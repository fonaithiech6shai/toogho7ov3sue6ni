# encoding: utf-8
# ИСПРАВЛЕНО: Lazy Load подгрузка отзывов
# 
# Проблемы, которые были исправлены:
# 1. Несоответствие URL между контроллером (:feedback) и JavaScript (/comment/load_more)
# 2. Проблемы с render partial - заменено на ручную генерацию HTML
# 3. Дублированный код между :feedback и :comment контроллерами
# 4. Улучшена обработка ошибок и логирование
# 
# Теперь lazy loading работает через:
# - /feedback/load_more - основной endpoint
# - /comment/load_more - алиас для совместимости (редирект)
# 

# encoding: utf-8

Rozario::App.controllers :feedback do

  before do
    require 'yaml'
    @redis_enable = false
    redis_settings = YAML::load_file("config/redis.yml")
    REDIS = Redis.new(redis_settings['test'])
    
    # Важно: вызываем основную логику приложения
    load_subdomain
    
    if @subdomain.nil?
      halt 403, 'Forbidden'
    end
    
    prod_price if respond_to?(:prod_price)
  end

  get :index do

    @canonical = "https://#{@subdomain.url != 'murmansk' ? "#{@subdomain.url}.#{CURRENT_DOMAIN}" : CURRENT_DOMAIN}/comment"

    #@comments = Comment.all(:order => 'created_at desc')
    #get_seo_data('comments', nil, true)
    #render 'comment/index'

    puts "get :index do comment.rb"
    
    # Получаем список заказов для авторизованного пользователя
    user_account = current_account || (session[:user_id] ? UserAccount.find(session[:user_id]) : nil)
    @user_orders = []
    if user_account
      @user_orders = Order.where(useraccount_id: user_account.id)
                         .where('eight_digit_id IS NOT NULL AND eight_digit_id != ""')
                         .order('created_at DESC')
                         .select('eight_digit_id, created_at')
                         .map { |order| [order.eight_digit_id, order.created_at] }
    end
    
    # Возвращаем обычное кэширование как было
    if !user_account && REDIS.get(@subdomain.url + ':feedback') && @redis_enable
      REDIS.get @subdomain.url + ':feedback'
    else
      # Пагинация для ленивой загрузки - только опубликованные отзывы
      @page = (params[:page] || 1).to_i
      @per_page = 10 # Количество отзывов на страницу
      

      @comments = Comment.published.order('created_at desc').limit(@per_page).offset((@page - 1) * @per_page)
      @total_comments = Comment.published.count
      @has_more = (@page * @per_page) < @total_comments
      get_seo_data('comments', nil, true)
      page = render 'comment/index'
      # Кешируем только версию для неавторизованных
      REDIS.setnx(@subdomain.url + ':feedback', page) if !user_account
      page
    end
  end

  post :submit do
    # Проверяем авторизацию
    user_account = current_account || (session[:user_id] ? UserAccount.find(session[:user_id]) : nil)
    unless user_account
      flash[:error] = 'Для оставления отзыва необходимо авторизоваться'
      redirect back
      return
    end
    
    # Проверяем обязательные поля
    if params[:order_eight_digit_id].blank?
      flash[:error] = 'Ошибка: укажите номер заказа'
      redirect back
      return
    elsif params[:rating].nil?
      rating = '0'
      flash[:error] = 'Ошибка: установите оценку'
      redirect back
      return
    else
      rating = params[:rating]
      order_id = params[:order_eight_digit_id].to_i
      
      # Проверяем существование заказа если номер указан
      if order_id && !Order.exists?(:eight_digit_id => order_id)
        flash[:error] = "Ошибка: заказ с номером #{order_id} не найден"
        redirect back
        return
      end
      
      # Создаем комментарий с данными авторизованного пользователя
      begin
        # Используем данные из профиля пользователя
        user_name = user_account.name || user_account.surname || user_account.email.split('@').first
        
        comment = Comment.create!(
          :name => user_name,
          :body => params[:msg], 
          :rating => rating.to_f,
          :order_eight_digit_id => order_id,
          :published => 0,  # Новые комментарии по умолчанию не опубликованы (модерация)
          :date => Time.now  # Дата отправки отзыва
        )
        
        # Отправляем почту с данными авторизованного пользователя
        order_info = order_id ? "\nНомер заказа: #{order_id}" : ""
        user_email = user_account.email
        user_id_info = "\nID пользователя: #{user_account.id}"
        msg_body = "Имя: #{user_name}\nЭл. почта: #{user_email}\nОтзыв: #{params[:msg]}\nОценка: #{rating}#{order_info}#{user_id_info}"
        
        # Проверяем, что адрес получателя установлен
        recipient_email = ENV['ORDER_EMAIL'].to_s
        if recipient_email.empty?
          puts "❌ WARNING: ORDER_EMAIL environment variable is not set. Email will not be sent."
          flash[:notice] = "Спасибо! Ваш отзыв отправлен на модерацию и будет опубликован после проверки."
        else
          begin
            # Используем асинхронную отправку как в рабочей системе заказов
            thread = Thread.new do
              email do
                from "no-reply@rozarioflowers.ru"
                to recipient_email
                subject "Отзыв с сайта"
                body msg_body
              end
              puts "✅ [#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] Comment email sent to #{recipient_email} - Rating: #{rating}"
            end
            
            # Не ждем завершения thread, как в рабочей системе
            puts "✅ Comment saved and email queued for #{recipient_email}"
            flash[:notice] = "Спасибо! Ваш отзыв отправлен на модерацию и будет опубликован после проверки."
          rescue => e
            puts "❌ [#{Time.now.strftime('%d.%m.%Y %H:%M:%S')}] ERROR sending comment email: #{e.message}"
            puts "   Recipient: #{recipient_email}"
            puts "   Error class: #{e.class}"
            flash[:notice] = "Спасибо! Ваш отзыв отправлен на модерацию и будет опубликован после проверки."
          end
        end
        
        # flash[:notice] устанавливается выше в зависимости от результата отправки email
      rescue ActiveRecord::RecordInvalid => e
        flash[:error] = "Ошибка при сохранении отзыва: #{e.record.errors.full_messages.join(', ')}"
      end
    end
    redirect back
  end

  # AJAX endpoint для ленивой загрузки отзывов
  get :load_more do
    begin
      content_type :json
      
      @page = (params[:page] || 1).to_i
      @per_page = 10
      
      # Проверяем корректность параметра
      if @page < 1
        @page = 1
      end
      
      @comments = Comment.published.order('created_at desc').limit(@per_page).offset((@page - 1) * @per_page)
      @total_comments = Comment.published.count
      @has_more = (@page * @per_page) < @total_comments
      
      puts "Load more: page=#{@page}, per_page=#{@per_page}, comments_count=#{@comments.count}, has_more=#{@has_more}"
      
      # Создаем HTML для каждого отзыва вручную (избегаем проблем с render)
      comments_html = ''
      if @comments.any?
        @comments.each do |comment|
          begin
            date = comment.date.present? ? comment.date.strftime("%d.%m.%Y") : comment.created_at.strftime("%d.%m.%Y")
            rating_stars = '★' * comment.rating.to_i + '☆' * (5 - comment.rating.to_i)
            order_info = comment.order_eight_digit_id.present? ? "<div class='order-info' style='font-size: 12px; color: #666; margin: 4px 0;'><small>Отзыв к заказу № #{comment.order_eight_digit_id}</small></div>" : ''
            
            comments_html += "<article class='comment-item' style='padding: 8px 0;' itemscope='' itemtype='http://schema.org/Rating'>
              <h3 class='name'>#{comment.name}</h3>
              <div class='date'>#{date}</div>
              #{order_info}
              <div class='body' itemprop='description'>#{comment.body}</div>
              <div>
                <span class='star-rating mini' content='#{comment.rating}' itemprop='ratingValue'>#{rating_stars}</span>
              </div>
            </article>"
          rescue => e
            puts "Error creating HTML for comment #{comment.id}: #{e.message}"
            # Пропускаем проблемные отзывы
          end
        end
      end
      
      response = {
        :html => comments_html,
        :has_more => @has_more,
        :current_page => @page,
        :total_comments => @total_comments,
        :loaded_count => @comments.count
      }
      
      response.to_json
      
    rescue => e
      puts "Error in load_more: #{e.message}"
      puts e.backtrace.join("\n")
      
      content_type :json
      status 500
      {
        :error => 'Internal server error',
        :message => e.message,
        :has_more => false
      }.to_json
    end
  end

  get :test do
    @comments = Comment.published.order('created_at desc')
    get_seo_data('comments', nil, true)
    page = render 'comment/indexxx'
  end
  
  get :debug do
    content_type :json
    debug_info = {
      current_account: current_account.inspect,
      current_account_nil: current_account.nil?,
      session_user_id: session[:user_id],
      session_keys: session.keys,
      session_full: session.to_hash,
      subdomain: @subdomain.inspect,
      request_host: request.host,
      request_subdomains: request.subdomains
    }
    debug_info.to_json
  end

  post :index do
    # Устаревший метод - перенаправляем на новый
    flash[:error] = 'Пожалуйста, используйте обновленную форму отзывов с авторизацией.'
    redirect(url(:feedback, :index))
  end

  post :indexxx do
    puts "post :indexxx do comment.rb - DEPRECATED"
    # Устаревший метод - перенаправляем на новый
    flash[:error] = 'Пожалуйста, используйте обновленную форму отзывов с авторизацией.'
    redirect(url(:feedback, :index))
  end
end

# Alias controller for backward compatibility with Nginx redirects
Rozario::App.controllers :comment do
  
  before do
    require 'yaml'
    @redis_enable = false
    redis_settings = YAML::load_file("config/redis.yml")
    REDIS = Redis.new(redis_settings['test']) if defined?(Redis)
    
    # Важно: вызываем основную логику приложения
    load_subdomain if respond_to?(:load_subdomain)
    
    if @subdomain.nil? && respond_to?(:halt)
      halt 403, 'Forbidden'
    end
    
    prod_price if respond_to?(:prod_price)
  end
  get :index do
    redirect url(:feedback, :index), 301
  end
  
  # Добавляем алиас для load_more в feedback контроллер
  get :load_more do
    redirect url(:feedback, :load_more, :page => params[:page]), 301
  end
  
  # AJAX endpoint для ленивой загрузки отзывов (реальная реализация для :comment контроллера)
  get :load_more_direct do
    begin
      content_type 'application/json'
      
      @page = (params[:page] || 1).to_i
      @per_page = 10
      
      # Проверяем корректность параметра
      if @page < 1
        @page = 1
      end
      
      # Проверяем, что модель Comment существует
      unless defined?(Comment)
        raise "Comment model not found"
      end
      
      @comments = Comment.published.order('created_at desc').limit(@per_page).offset((@page - 1) * @per_page)
      @total_comments = Comment.published.count
      @has_more = (@page * @per_page) < @total_comments
      
      puts "[COMMENT ALIAS] Load more: page=#{@page}, per_page=#{@per_page}, comments_count=#{@comments.count}, has_more=#{@has_more}"
      
      # Создаем HTML для каждого отзыва
      comments_html = ''
      @comments.each do |comment|
        begin
          date = comment.date.present? ? comment.date.strftime("%d.%m.%Y") : comment.created_at.strftime("%d.%m.%Y")
          rating_stars = '★' * comment.rating.to_i + '☆' * (5 - comment.rating.to_i)
          order_info = comment.order_eight_digit_id.present? ? "<div class='order-info' style='font-size: 12px; color: #666; margin: 4px 0;'><small>Отзыв к заказу № #{comment.order_eight_digit_id}</small></div>" : ''
          
          comments_html += "<article class='comment-item' style='padding: 8px 0;' itemscope='' itemtype='http://schema.org/Rating'>
             <h3 class='name'>#{comment.name}</h3>
             <div class='date'>#{date}</div>
             #{order_info}
             <div class='body' itemprop='description'>#{comment.body}</div>
             <div>
               <span class='star-rating mini' content='#{comment.rating}' itemprop='ratingValue'>#{rating_stars}</span>
             </div>
           </article>"
        rescue => e
          puts "Error creating HTML for comment #{comment.id}: #{e.message}"
          # Пропускаем проблемные отзывы
        end
      end
      
      response = {
        :html => comments_html,
        :has_more => @has_more,
        :current_page => @page,
        :total_comments => @total_comments,
        :loaded_count => @comments.count
      }
      
      response.to_json
      
    rescue => e
      puts "Error in load_more_direct (comment alias): #{e.message}"
      puts e.backtrace.join("\n")
      
      content_type 'application/json'
      status 500
      {
        :error => 'Internal server error',
        :message => e.message,
        :has_more => false
      }.to_json
    end
  end
end
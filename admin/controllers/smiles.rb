# encoding: utf-8
Rozario::Admin.controllers :smiles do

  # Хелпер для форматирования даты в русском формате
  def format_russian_date(date_string)
    return nil if date_string.blank?
    
    begin
      # Парсим дату из строки или объекта Date/DateTime
      if date_string.is_a?(String)
        if date_string.include?('/')
          # Формат d/m/Y или dd/mm/yyyy
          parsed_date = Date.strptime(date_string, '%d/%m/%Y')
        else
          # Пробуем стандартное форматирование
          parsed_date = Date.parse(date_string)
        end
      else
        parsed_date = date_string.to_date
      end
      
      # Массивы для русских названий месяцев
      russian_months = {
        1 => 'января', 2 => 'февраля', 3 => 'марта', 4 => 'апреля',
        5 => 'мая', 6 => 'июня', 7 => 'июля', 8 => 'августа',
        9 => 'сентября', 10 => 'октября', 11 => 'ноября', 12 => 'декабря'
      }
      
      day = parsed_date.day
      month = russian_months[parsed_date.month]
      year = parsed_date.year
      
      return "#{day} #{month} #{year} года"
    rescue => e
      puts "ОШИБКА форматирования даты #{date_string}: #{e.message}"
      return nil
    end
  end
  
  # Хелпер для автоматического заполнения даты из заказа
  def auto_fill_date_from_order(order_eight_digit_id, current_date = nil)
    # Если дата уже заполнена, не перезаписываем
    return current_date if current_date.present? && current_date.strip != ''
    
    return nil if order_eight_digit_id.blank?
    
    begin
      order = Order.find_by_eight_digit_id(order_eight_digit_id.to_i)
      return nil if order.nil?
      
      # Получаем d2_date из заказа
      d2_date = order.d2_date
      return nil if d2_date.blank?
      
      # Форматируем дату в русский формат
      formatted_date = format_russian_date(d2_date)
      
      puts "DEBUG: Автозаполнение даты для заказа #{order_eight_digit_id}: #{d2_date} => #{formatted_date}"
      
      return formatted_date
    rescue => e
      puts "ОШИБКА получения даты заказа #{order_eight_digit_id}: #{e.message}"
      return nil
    end
  end

  get :index do
    filter = params[:filter]
    @title = "Улыбки наших покупателей"
    @filter_type = 'all'
    #@slideshows = Slideshow.all
    if filter == "sidebar"
      @smile = Smile.where(sidebar: true).order('updated_at DESC, id DESC').paginate(:page => params[:page], :per_page => 20)
      render 'smiles/index'
    end

    @smile = Smile.order('updated_at DESC, id DESC').paginate(:page => params[:page], :per_page => 20)
    render 'smiles/index'
  end
  
  # Новая вкладка для неопубликованных смайлов
  get :unpublished do
    @title = "Unpublished Smiles"
    @smile = Smile.where(published: 0).order('updated_at DESC, id DESC').paginate(:page => params[:page], :per_page => 20)
    @filter_type = 'unpublished'
    render 'smiles/index'
  end

  get :new do
    @title = pat(:new_title, :model => 'smile')

    @product = []
    product  = Product.pluck(:id).map(&:to_s).zip(Product.pluck(:header).map(&:to_s))
    product.each do |id, name|
      @product += [id.to_s + " - " + name.to_s]
    end
    @smile = Smile.new
    @smile.seo = Seo.new
    render 'smiles/new'
  end

  post :create do
    json_order = params[:smile][:order]
    smile_params = params[:smile]
    
    # Разрешаем необходимые параметры, включая поле date для текстовой даты
    allowed_params = smile_params.select { |k, v| 
      ['title', 'slug', 'body', 'images', 'rating', 'alt', 'smile_text', 'sidebar', 'order_eight_digit_id', 'order_products_base_id', 'seo_attributes', 'published', 'date'].include?(k) 
    }
    
    # Обработка BIT поля published для MySQL
    published_value = smile_params.has_key?('published') ? smile_params['published'] : '0'
    published_int = (published_value == '1' || published_value == 1) ? 1 : 0
    allowed_params['published'] = published_int
    
    # Debug info
    puts "DEBUG CREATE: published checkbox #{smile_params.has_key?('published') ? 'checked' : 'unchecked'}, raw: #{published_value.inspect}, final: #{published_int}"
    puts "DEBUG CREATE: date field value: #{allowed_params['date'].inspect}"
    
    # Автоматическое заполнение даты из заказа при указании order_eight_digit_id
    if allowed_params['order_eight_digit_id'].present? && allowed_params['order_eight_digit_id'].to_s.strip != ''
      auto_filled_date = auto_fill_date_from_order(allowed_params['order_eight_digit_id'], allowed_params['date'])
      allowed_params['date'] = auto_filled_date if auto_filled_date.present?
      puts "DEBUG CREATE: Автозаполнение даты: #{auto_filled_date}"
    end
    
    # Логика для json_order: если указан номер заказа, используем NULL
    @smile = Smile.new(allowed_params)
    @smile[:slug] = @smile[:title].to_lat unless @smile[:slug].present?
    
    if allowed_params['order_eight_digit_id'].present? && allowed_params['order_eight_digit_id'].to_s.strip != ''
      # При наличии номера заказа обнуляем json_order
      @smile[:json_order] = nil
      puts "DEBUG CREATE: order_eight_digit_id присутствует (#{allowed_params['order_eight_digit_id']}), json_order установлен в NULL"
    else
      # При отсутствии номера заказа сохраняем данные о продуктах
      hash = {}
      if json_order && json_order[:products_names]
        json_order[:products_names].each.with_index do |j, i|
          hash[i] = [["id", j[1].split(' - ')[0]], ["complect", json_order[:products_components][i.to_s]]].to_h if j[1].present?
        end
      end
      @smile[:json_order] = hash.to_json
      puts "DEBUG CREATE: order_eight_digit_id отсутствует, json_order сохранён: #{@smile[:json_order]}"
    end
    if @smile.save
      # Для BIT поля может потребоваться прямой SQL запрос
      if allowed_params.has_key?('published')
        sql = "UPDATE smiles SET published = #{published_int} WHERE id = #{@smile.id}"
        ActiveRecord::Base.connection.execute(sql)
        puts "DEBUG CREATE: executed direct SQL: #{sql}"
      end
      
      # Проверяем что фактически сохранилось
      @smile.reload
      puts "DEBUG CREATE: smile after save: #{@smile.published.inspect} (#{@smile.published.class})"
      
      @title = pat(:create_title, :model => "smile #{@smile.id}")
      flash[:success] = pat(:create_success, :model => 'Smile')
      params[:save_and_continue] ? redirect(url(:smiles, :index)) : redirect(url(:smiles, :edit, :id => @smile.id))
    else
      @title = pat(:create_title, :model => 'smile')
      flash.now[:error] = pat(:create_error, :model => 'smile')
      render 'smiles/new'
    end
  end

  get :edit, :with => :id do
    @title = pat(:edit_title, :model => "smiles #{params[:id]}")
    @smile = Smile.find(params[:id])
    @smile.seo = Seo.new unless @smile.seo.present?
    @product = []
    product  = Product.all
    product.each do |p|
      @product += [p.id.to_s + " - " + p.header.to_s]
    end
    @json_order = {}
    @product_n = []
    @product_c = []
    if @smile
      # Проверяем, что json_order не NULL и не пустое
      if @smile.json_order.present? && @smile.json_order.strip != ''
        begin
          JSON.parse(@smile.json_order).each do |num, o|
            name = o['id'].to_s + " - " + Product.find(o['id']).header
            @json_order[num] = {name: name, component: o['complect']}
            @product_n[num.to_i] = name
            @product_c[num.to_i] = o['complect']
          end
        rescue JSON::ParserError => e
          puts "DEBUG EDIT: Ошибка парсинга json_order: #{e.message}"
          # Оставляем пустые массивы
        end
      else
        puts "DEBUG EDIT: json_order пустое или NULL, используем пустые массивы"
      end
      render 'smiles/edit'
    else
      flash[:warning] = pat(:create_error, :model => 'smile', :id => "#{params[:id]}")
      halt 404
    end
  end

  put :update, :with => :id do
    json_order = params[:smile][:order]
    @title = pat(:update_title, :model => "smile #{params[:id]}")
    @smile = Smile.find(params[:id])
    smile_params = params[:smile]
    
    # Разрешаем необходимые параметры, включая поле date для текстовой даты
    allowed_params = smile_params.select { |k, v| 
      ['title', 'slug', 'body', 'images', 'rating', 'alt', 'smile_text', 'sidebar', 'order_eight_digit_id', 'order_products_base_id', 'seo_attributes', 'published', 'date'].include?(k) 
    }
    
    # Обработка BIT поля published для MySQL
    published_value = smile_params.has_key?('published') ? smile_params['published'] : '0'
    published_int = (published_value == '1' || published_value == 1) ? 1 : 0
    allowed_params['published'] = published_int
    
    # Debug info
    puts "DEBUG UPDATE: published checkbox #{smile_params.has_key?('published') ? 'checked' : 'unchecked'}, raw: #{published_value.inspect}, final: #{published_int}"
    puts "DEBUG UPDATE: date field value: #{allowed_params['date'].inspect}"
    
    # Автоматическое заполнение даты из заказа при указании order_eight_digit_id
    if allowed_params['order_eight_digit_id'].present? && allowed_params['order_eight_digit_id'].to_s.strip != ''
      auto_filled_date = auto_fill_date_from_order(allowed_params['order_eight_digit_id'], allowed_params['date'])
      allowed_params['date'] = auto_filled_date if auto_filled_date.present?
      puts "DEBUG UPDATE: Автозаполнение даты: #{auto_filled_date}"
    end
    
    # Логика для json_order: если указан номер заказа, используем NULL
    if allowed_params['order_eight_digit_id'].present? && allowed_params['order_eight_digit_id'].to_s.strip != ''
      # При наличии номера заказа обнуляем json_order
      allowed_params[:json_order] = nil
      puts "DEBUG UPDATE: order_eight_digit_id присутствует (#{allowed_params['order_eight_digit_id']}), json_order установлен в NULL"
    else
      # При отсутствии номера заказа сохраняем данные о продуктах
      hash = {}
      if json_order && json_order[:products_names]
        json_order[:products_names].each.with_index do |j, i|
          hash[i] = [["id", j[1].split(' - ')[0]], ["complect", json_order[:products_components][i.to_s]]].to_h if j[1].present?
        end
      end
      allowed_params[:json_order] = hash.to_json
      puts "DEBUG UPDATE: order_eight_digit_id отсутствует, json_order сохранён: #{allowed_params[:json_order]}"
    end
    if @smile
      update_params = allowed_params
      if @smile.update_attributes(update_params)
        # Для BIT поля может потребоваться прямой SQL запрос
        if update_params.has_key?('published')
          sql = "UPDATE smiles SET published = #{published_int} WHERE id = #{@smile.id}"
          ActiveRecord::Base.connection.execute(sql)
          puts "DEBUG UPDATE: executed direct SQL: #{sql}"
        end
        
        # Проверяем что фактически сохранилось
        @smile.reload
        puts "DEBUG UPDATE: smile after save: #{@smile.published.inspect} (#{@smile.published.class})"
        
        flash[:success] = pat(:update_success, :model => 'Smile', :id =>  "#{params[:id]}")
        params[:save_and_continue] ?
          redirect(url(:smiles, :index)) :
          redirect(url(:smiles, :edit, :id => @smile.id))
      else
        flash.now[:error] = pat(:update_error, :model => 'smiles')
        render 'smiles/edit'
      end
    else
      flash[:warning] = pat(:update_warning, :model => 'smile', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy, :with => :id do
    @title = "Smile"
    smile = Smile.find(params[:id])
    if smile
      if smile.destroy
        flash[:success] = pat(:delete_success, :model => 'Smile', :id => "#{params[:id]}")
      else
        flash[:error] = pat(:delete_error, :model => 'smile')
      end
      redirect url(:smiles, :index)
    else
      flash[:warning] = pat(:delete_warning, :model => 'smiles', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy_many do
    @title = "Smiles"
    unless params[:smile_ids]
      flash[:error] = pat(:destroy_many_error, :model => 'smile')
      redirect(url(:smiles, :index))
    end
    ids = params[:smile_ids].split(',').map(&:strip).map(&:to_i)
    smile = Smile.find(ids)

    if Smile.destroy smile

      flash[:success] = pat(:destroy_many_success, :model => 'Smile', :ids => "#{ids.to_sentence}")
    end
    redirect url(:smiles, :index)
  end

  # API endpoint для получения состава заказа
  get '/order_products/:order_id' do
    content_type :json
    
    begin
      order_eight_digit_id = params[:order_id].to_i
      
      # Находим заказ по eight_digit_id
      order = Order.find_by_eight_digit_id(order_eight_digit_id)
      
      if order.nil?
        return { error: "Заказ с номером #{order_eight_digit_id} не найден" }.to_json
      end
      
      # Получаем товары из заказа (в таблице order_products поле id является FK на orders.id)
      cart_items = Order_product.find_by_sql("SELECT * FROM order_products WHERE id = #{order.id}")
      
      if cart_items.empty?
        return { error: "В заказе #{order_eight_digit_id} нет товаров" }.to_json
      end
      
      # Формируем массив товаров с подробной информацией
      products = cart_items.map do |item|
        begin
          product = Product.find_by_id(item.product_id)
          complect = Complect.find_by_title(item.typing) if item.typing
          
          {
            base_id: item.base_id,  # Добавляем base_id из order_products
            id: item.product_id,
            title: item.title || (product ? product.header : "Товар не найден"),
            price: item.price,
            quantity: item.quantity,
            typing: item.typing || "standard",
            complect_name: complect ? complect.header : item.typing,
            product_exists: !product.nil?
          }
        rescue => e
          {
            base_id: item.respond_to?(:base_id) ? item.base_id : nil,  # Безопасно получаем base_id
            id: item.product_id,
            title: item.title || "Ошибка загрузки товара",
            price: item.price,
            quantity: item.quantity,
            typing: item.typing || "standard",
            complect_name: item.typing,
            product_exists: false,
            error: e.message
          }
        end
      end
      
      # Получаем дополнительную информацию для автозаполнения
      customer_name = nil
      recipient_name = order.dname.present? ? order.dname.strip : nil
      
      if order.useraccount_id && order.useraccount_id > 0
        user_account = UserAccount.find_by_id(order.useraccount_id)
        if user_account
          if user_account.surname && user_account.surname.present? && user_account.surname.strip.length > 0
            customer_name = user_account.surname.strip
          elsif user_account.name && user_account.name.present? && user_account.name.strip.length > 0
            customer_name = user_account.name.strip
          end
        end
      end
      
      # Получаем название первого товара для main_product_name
      main_product_name = products.first ? products.first[:title] : ""
      
      {
        success: true,
        order_id: order_eight_digit_id,
        customer_name: customer_name,
        recipient_name: recipient_name,
        main_product_name: main_product_name,
        order_date: order.created_at ? order.created_at.strftime('%d.%m.%Y') : Time.now.strftime('%d.%m.%Y'),
        products: products
      }.to_json
      
    rescue => e
      { error: "Ошибка получения данных заказа: #{e.message}" }.to_json
    end
  end

  get :search do
    type = params['type']
    query = strip_tags(params[:query]).mb_chars.downcase

    if params[:query].length > 0
      @smile = Smile.where("#{type} like ?", "%#{query}%").order('updated_at DESC, id DESC').paginate(:page => params[:page], :per_page => 20)
      if @smile.first.nil?
        flash[:error] = "Ничего не найдено :("
        redirect back
      else
        flash[:success] = "Найдено"
        render 'smiles/index'
      end
    else
      @smile = Smile.order('updated_at DESC, id DESC').paginate(:page => params[:page], :per_page => 20)
      flash[:error] = "Введите запрос"
      render 'smiles/index'
    end
  end
end

  # Тестовый метод для проверки форматирования дат (только для разработки)
  get :test_date_format do
    content_type :json
    
    test_dates = [
      '15/09/2023',
      '01/12/2024', 
      '28/02/2025',
      DateTime.now,
      Date.today
    ]
    
    results = test_dates.map do |date|
      {
        input: date.to_s,
        formatted: format_russian_date(date)
      }
    end
    
    { test_results: results }.to_json
  end
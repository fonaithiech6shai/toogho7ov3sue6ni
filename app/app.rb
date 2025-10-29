# encoding: utf-8

require 'time'
require 'connection_pool'
require 'commonmarker'
require 'ostruct'

require 'multi_captcha'


# boundID45456546
require Padrino.root('app/dsc.rb')
class DscntClass
  include DscntModule
end

# boundID39929389
if !ENV['RECAPTCHA_V3_SITE_KEY'].empty? && !ENV['RECAPTCHA_V3_SECRET_KEY'].empty?
  require 'recaptcha'
  Recaptcha.configure do |config| # reCAPTCHA v3
    config.site_key   = ENV['RECAPTCHA_V3_SITE_KEY']
    config.secret_key = ENV['RECAPTCHA_V3_SECRET_KEY']
  end
  include Recaptcha::ClientHelper
  include Recaptcha::Verify
end

module Rozario
  class App < Padrino::Application

    CURRENT_DOMAIN = 'rozarioflowers.ru'
    CURRENT_DOMAIN_DEVELOPMENT = 'entropyrise.ru'
    # CURRENT_DOMAIN_FULL = @subdomain.url != 'murmansk' ? "#{@subdomain.url}.#{CURRENT_DOMAIN}" : CURRENT_DOMAIN

    use ActiveRecord::ConnectionAdapters::ConnectionManagement

    #use Rack::Recaptcha, :public_key => '6LfHoesSAAAAAIaCozRMCR9R2olUILtLMyqab3oZ', :private_key => '6LfHoesSAAAAAOrBNEcqu1bhp2yGxn0-sLs60OZd'
    #helpers Rack::Recaptcha::Helpers

    register RecatpchaInitializer
    register Padrino::Rendering
    register Padrino::Mailer
    register Padrino::Helpers
    register Sinatra::SimpleNavigation
    register Padrino::Admin::AccessControl
    register WillPaginate::Sinatra
    register Padrino::Cookies
    register Sidekiq::Worker

    # $REDISKA = Redis.new( # `ACL SETUSER username on >password ~rack:attack:* +@write +@read +@fast` или `ACL SETUSER username on >password ~* +@write +@read +@fast` или `ACL SETUSER username ~* +@write +@read +@fast`, ещё `ACL LIST` # `redis-cli -u redis://muticaptcha:e274f4065ad1c1c535ded9ea4e8430e28497380c2d15ab6817ebdc025ccbaae4@127.0.0.1:6379`
    #   host: '127.0.0.1', port: 6379,
    #   username: 'muticaptcha', password: 'e274f4065ad1c1c535ded9ea4e8430e28497380c2d15ab6817ebdc025ccbaae4'
    #   # connect_timeout: 5, # Тайм-аут подключения
    #   # read_timeout: 5,    # Тайм-аут чтения
    #   # write_timeout: 5    # Тайм-аут записи
    # )

    # if    PADRINO_ENV == 'development'; $REDISKA = Redis.new(url: "redis://:#{ENV['REDIS_PASSWORD'].to_s}@127.0.0.1:6379/0"); $REDISKA.flushdb()
    # elsif PADRINO_ENV == 'production';  $REDISKA = Redis.new(url: "redis://:#{ENV['REDIS_PASSWORD'].to_s}@127.0.0.1:6379/1"); $REDISKA.flushdb(); end

    # redis_pool = ConnectionPool.new(size: 5, timeout: 5) do
    #   Redis.new(
    #     host: '127.0.0.1',    # ENV['REDIS_HOST']
    #     port: 6379,           # ENV['REDIS_PORT'].to_i
    #     db: 0,                # ENV['REDIS_DB'].to_i
    #     password: ENV['REDIS_PASSWORD'].to_s,
    #     inherit_socket: true  # Опция `inherit_socket` в Redis-клиенте действительно предназначена для того, чтобы использовать одно соединение между процессами после форка. Однако это не всегда гарантирует корректную работу в многозадачных средах, особенно при использовании `ConnectionPool` или когда Redis подключается в рамках нескольких процессов или потоков. Вместо того чтобы полагаться на `inherit_socket`, более надежным подходом будет переинициализация соединений с Redis после форка.
    #   )
    # end

    # multi_captcha_logger = Logger.new(File.join(Padrino.root, 'log', 'multi_captcha.log'))
    # multi_captcha_logger.level = Logger::DEBUG # Устанавливаем уровень логирования
    # # MultiCaptcha.default_logger = multi_captcha_logger # Устанавливаем дефолтный логгер для всего гема
    # MultiCaptcha.configure { |config|
    #   config.redis_pool = $redis_pool
    #   config.site_key   = ENV['CLOUDFLARE_TURNSTILE_SITE_KEY'] # Важно: используйте переменную окружения
    #   config.secret_key = ENV['CLOUDFLARE_TURNSTILE_SECRET_KEY'] # Используется в хелперах
    #   config.failure_app = lambda { |env|
    #     [403, {'Content-Type' => 'text/html'}, ["<h1>Captcha verification failed. Please try again.</h1>"]]
    #   }
    #   config.logger = multi_captcha_logger
    #   config.turnstile_field_name = 'cf-turnstile-response'
    #   config.exempt_paths = ['/assets', '/api', '/favicon.ico']
    # }
    # MultiCaptcha.configure_rack_attack
    # use Rack::Attack
    # use MultiCaptcha::SansScriptBlocker


    if PADRINO_ENV == 'production'
      set :host, "https://#{CURRENT_DOMAIN}"
      register Padrino::Cache # Includes helpers
      enable :caching         # Turn cache up!
      Padrino.cache.flush     # In for a penny, in for a pound...
    elsif PADRINO_ENV == 'development'
      set :host, "https://#{CURRENT_DOMAIN_DEVELOPMENT}"
      disable :caching
      enable :reload
      # helpers MultiCaptcha::Helpers
      # use MultiCaptcha::Middleware # Должен быть перед любым middleware, который обрабатывает параметры формы
      use Rack::MiniProfiler if ENV['RACK_ENV'] == 'development'
    end

    # Padrino.cache = Padrino::Cache::Store::File.new(Dir.pwd + "/tmp/cache")
    # Padrino.cache = Padrino::Cache::Store::Memory.new(50)
    # Padrino.cache = Padrino::Cache::Store::Redis.new(::Redis.new(:host => '127.0.0.1', :port => 6379, :password => ENV['REDIS_PASSWORD'].to_s, :db => 0))

    # set :cache, Padrino::Cache::Store::Redis.new( # Настройка кэша Redis
    #   host: '127.0.0.1',
    #   port: 6379,
    #   password: ENV['REDIS_PASSWORD'].to_s,
    #   db: 0
    # )


    set :admin_model, 'UserAccount'
    set :login_page,  '/sessions/new'

    enable :sessions
    enable :authentication
    # set :reload, false          # Reload application files (default in development)
    #  set :delivery_method, :smtp => {
    #    :address         => 'smtp.yourserver.com',
    #    :port            => '25',
    #    :user_name       => 'user',
    #    :password        => 'pass',
    #    :authentication  => :plain
    #  }
    #  set :delivery_method, :sendmail

    set :delivery_method, :sendmail

    # Простая настройка сессий без домена
    set :sessions, 
      key: '_roz_session',
      secret: 'kljasd9asdjkh442rf7h34fjkbn34f7h##$%c45c53544'

    access_control.roles_for :any do |role|
      #role.protect '/' #
      role.allow   '/sessions' #
      role.project_module :user_accounts, '/user_accounts'
    end

    # use Rack::Cors do
    #   allow do
    #     # put real origins here
    #     origins '*'
    #     # and configure real resources here
    #     resource '*', :headers => :any, :methods => [:get, :post, :options]
    #   end
    # end
    
    require 'cyrillizer'
    Cyrillizer.alphabet = "lib/alphabet/russian.yml" # path to the alphabet
    
    before do

      # boundID34985439
      @environment = {}; @environment['type'] = 'development';

      load_subdomain

      if @subdomain.nil?
        if request.path_info.start_with?('/sessions')
          # Для страниц сессий создаем заглушку для @subdomain
          @subdomain = OpenStruct.new(id: nil, url: 'default', city: 'Default')
        else
          halt 403, 'Forbidden' # Останавливает обработку и отправляет 403
        end
      end

      prod_price

      headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Origin, Authorization"
      response.headers.delete('X-Powered-By')
      response.headers.delete('server')

      #@banner_file = File.basename(Dir[File.join(Padrino.root, "public", "uploads", "options") + "/*"].take(1)[0])

      @latest_news = News.all(:order => 'created_at desc', :limit => 3)

      @subdomain_pool = SubdomainPool.where(id: @subdomain.subdomain_pool_id).first

      @left_menu = Leftmenu.where(default: true).first
      if @subdomain_pool.leftmenu_id and @subdomain_pool.enable_categories
        @left_menu = Leftmenu.where(id: @subdomain_pool.leftmenu_id).first
      end
      if @subdomain.leftmenu_id and @subdomain.enable_categories
        @left_menu = Leftmenu.where(id: @subdomain.leftmenu_id).first
      end
      @lf_catlist = LeftmenuCats.where(leftmenu_id: @left_menu.id)

      #puts '--------------------------------------------------------------------------------------------'
      #@lf_catlist.each { |e|
      #  puts e.to_json
      #}
      #puts '--------------------------------------------------------------------------------------------'

      @all_cats = Category.where(:show_in_index => true).order('sort_index asc')

      if @subdomain_pool.enable_categories
        sbdp_cgs = CategoriesCategorygroup.where(categorygroup_id: @subdomain_pool.categorygroup_ids).pluck(:category_id)
        tmpp_ids = sbdp_cgs + @subdomain_pool.category_ids + (@lf_catlist.pluck(:category_id))
        @all_cats = Category.where(id: tmpp_ids)
      end
      if @subdomain.enable_categories
        sbd_cgs= CategoriesCategorygroup.where(categorygroup_id: @subdomain.categorygroup_ids).pluck(:category_id)
        tmp_ids = sbd_cgs + Category.where(id: @subdomain.subdom_cat_ids) + @lf_catlist.pluck(:category_id)
        @all_cats = Category.where(id: tmp_ids.uniq)
      end

      @slideshow = Slideshow.where(:default => true).first
      if @subdomain_pool && @subdomain_pool.enable_slideshows
        @slideshow = Slideshow.where(id: @subdomain_pool.slideshow_main_id).first
      end
      if @subdomain && @subdomain.enable_slideshows
        @slideshow = Slideshow.where(id: @subdomain.slideshow_main_id).first
      end

      # boundID45456546
      if DscntClass.new.some_method.include?(@subdomain.url); @subdsc = DscntClass.new.some_method[@subdomain.url]
      else; @subdsc = {}; end

      # boundID34985439
      require 'yaml'
      @redis_enable = false
      redis_settings = YAML::load_file("config/redis.yml")
      $REDIS = Redis.new(redis_settings[@environment['type']])

    end

    def log_session_info(stage)
      puts "Getting session on get /"
      puts "session #{stage}"
      puts session[:mdata]
      puts request.session[:mdata]
      puts session
      puts request.session
    end

    def fetch_categories
      if @subdomain&.enable_categories; Category.where(id: @subdomain.category_ids.to_s.split(','), show_in_index: true).order('sort_index asc')
      else; Category.where(show_in_index: true).order('sort_index asc'); end
    end

    def get_items(categories, tags, min_price, max_price, sort_by, limit, page)
      items = Product.get_catalog(@subdomain, @subdomain_pool, categories, tags, min_price, max_price, sort_by)
      need_pagination = items.size > limit
      items = items.slice(limit * page, limit)
      return [items, need_pagination]
    end

    # get '/testing' do
    #   require 'yaml'
    #   require 'redis'
    #   $REDIS = Redis.new(host: "127.0.0.1", port: 6379, password: ENV['REDIS_PASSWORD'].to_s)
    #   # $REDIS = Redis.new(YAML::load_file("config/redis.yml")[@environment['type']])
    #   $REDIS.ping
    #   $REDIS.set("qwerty", 'test')
    # end
    # get '/testing' do
    #   # cache_control :no_cache
    #   # require 'yaml'
    #   # require 'redis'
    #   # $REDIS = Redis.new(host: "127.0.0.1", port: 6379, password: ENV['REDIS_PASSWORD'].to_s)
      
    #   # # Проверка, что Redis отвечает
    #   # response = $REDIS.ping
    #   # puts "PING Response: #{response}" # Ожидаем "PONG"
      
    #   # # Попытка установить значение
    #   # set_result = $REDIS.set("qwerty", 'test')
    #   # puts "SET Result: #{set_result}" # Ожидаем "OK"
      
    #   # # Проверка, что значение установлено
    #   # get_result = $REDIS.get("qwerty")
    #   # puts "GET Result: #{get_result}" # Ожидаем "test"

    #   # # Вернем значение для убедительности
    #   # get_result

    #   require 'redis'
    #   redis = Redis.new(host: '127.0.0.1', port: 6379, password: ENV['REDIS_PASSWORD'].to_s, db: 0)
    #   redis.set("test_key", "test_value")
    #   redis.get("test_key")
    # end

    # get '/set_session' do
    #   session[:message] = "Hello, Redis session! #{Time.now}"
    #   session_id = request.session_options[:id]
    #   "Session set! Session ID: #{session_id}"
    # end

    # get '/get_session' do
    #   "Session message: #{session[:message]}"
    # end

    # get '/tester' do
    #   content_type :text
    #   result = []
    #   cart = Order_product.find_by_sql("SELECT * FROM order_products WHERE id = 79678")
    #   cart.each { |order_product|
    #     complect_id = Complect.where(header: order_product.typing).first.id
    #     product_complect = ProductComplect.where(product_id: order_product.product_id, complect_id: complect_id).first
    #     result.append(product_complect.get_price(dp_id=@subdomain.discount_pool_id))
    #   }
    #   return result.join('.')
    # end

    # get '/tester' do
    #   content_type :json
    #   collector = []
    #   pages = [
    #     { name: 'category', type: Category, update: 'daily',   priority: 0.9 },
    #   ]
    #   pages.each do |page|
    #     Category.includes(:seo).where(seos: { index: true }).all.each do |a|
    #       if page[:name] == 'category' then
    #         if (a.level > 1)
    #           parent_category = Category.find(a.parent_id)
    #           collector.append({link: "#{page[:name]}/#{parent_category.slug ? parent_category.slug : parent_category.id.to_s}/#{a.slug ? a.slug : a.id.to_s}", mark: a.level})
    #         else
    #           collector.append({link: "#{page[:name]}/#{a.slug ? a.slug : a.id.to_s}", mark: a.level})
    #         end
    #       end
    #     end
    #   end
    #   return collector.to_json
    # end

    # get '/tester' do
    #   # Проверяем, переданы ли параметры в URL
    #   if params[:param1] && params[:param2]
    #     # Сохраняем параметры в сессии
    #     session[:param1] = params[:param1]
    #     session[:param2] = params[:param2]

    #     # Редиректим на тот же путь, но без параметров в URL
    #     redirect '/tester', 301
    #   else
    #     # Если параметры нет в URL, но они есть в сессии, показываем их
    #     param1 = session[:param1]
    #     param2 = session[:param2]

    #     # Выводим параметры
    #     return "param1: #{param1} param2: #{param2}"
    #   end
    # end

    # get '/tester' do
    #   response['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate'
    #   response['Pragma'] = 'no-cache'
    #   response['Expires'] = '0'
    #   if params[:param1] && params[:param2] # Получаем параметры
    #     session[:param1] = params[:param1]
    #     session[:param2] = params[:param2]
    #     return redirect '/tester', 301 # Редирект на чистый URL без параметров
    #   else
    #     if session[:param1] && session[:param2]
    #       param1 = session[:param1]
    #       param2 = session[:param2]
    #       session[:param1] = nil
    #       session[:param2] = nil
    #     else
    #       param1 = 'default'
    #       param2 = 'default'
    #     end
    #     # return "param1: #{param1} param2: #{param2}"
    #     return render 'tester', layout: false , locals: { param1: param1, param2: param2 } # Используем параметры для рендеринга
    #   end
    # end

    # get '/tester' do
    #   response['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate'
    #   response['Pragma'] = 'no-cache'
    #   response['Expires'] = '0'
    #   if params[:param1] && params[:param2] # Проверяем, переданы ли параметры в URL
    #     $REDIS.set(session.id, {:param1 => params[:param1], :param2 => params[:param2]}.to_json)
    #     # return "#{session.id} | #{$REDIS.get(session.id)}"
    #     redirect '/tester', 301 # Редиректим на тот же путь, но без параметров в URL
    #   else
    #     if $REDIS.get(session.id)
    #       data = JSON.parse($REDIS.get(session.id))
    #       $REDIS.del(session.id)
    #       # return "#{session.id} | #{$REDIS.get(session.id)}"
    #       return "#{session.id} | param1: #{data["param1"]} param2: #{data["param2"]}"
    #     else
    #       param1 = 'default'
    #       param2 = 'default'
    #       return render 'tester', layout: false , locals: { param1: param1, param2: param2 } # Используем параметры для рендеринга
    #     end
    #   end
    # end

    # get '/tester_2' do

    #   $REDIS.flushdb

    #   # Проверка, что Redis отвечает
    #   response = $REDIS.ping
    #   # return "PING Response: #{response}" # Ожидаем "PONG"
      
    #   # Попытка установить значение
    #   set_result = $REDIS.set(session.id, 'test')
    #   # return "SET Result: #{set_result}" # Ожидаем "OK"

    #   # Проверка, что значение установлено
    #   get_result = $REDIS.get(session.id)
    #   return "GET Result: #{get_result}" # Ожидаем "test"
    # end


    # get '/tester' do # DANGER!!!
    #   content_type :txt
    #   return ENV['PADRINO_SESSION_SECRET'] + '\n' + ENV['REDIS_PASSWORD'] + '\n' + ENV['MYSQL_PASSWORD']
    # end

    get '/' do

      @canonical = "https://#{@subdomain.url != 'murmansk' ? "#{@subdomain.url}.#{CURRENT_DOMAIN}" : CURRENT_DOMAIN}"

      if    PADRINO_ENV == 'production';  expires 3600 # * 24 * 7
      elsif PADRINO_ENV == 'development'; expires 0; end

      # log_session_info("before init")

      current_date = session[:mdata] || Date.current
      session[:mdata] ||= current_date

      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      date_begin = Date.new(2019, 3, 23).to_s
      date_end = Date.new(2019, 3, 25).to_s
      subd = session[:subdomain]
      value = (current_date.to_s >= date_begin && current_date.to_s <= date_end).to_s

      ProductComplect.check(value)
      Product.subd(subd)

      # log_session_info("after init")

      @sess = session[:mdata]
      page = Page.find_by_uri('index')
      get_seo_data('home_page', nil, true)
      @catlist = fetch_categories
      min_price = params[:min_price].blank? ? 0 : params[:min_price].to_i
      max_price = params[:max_price].blank? ? 1_000_000 : params[:max_price].to_i

      if @subdomain.enable_categories || @subdomain_pool.enable_categories
        category_ids = @all_cats.pluck(:id)
        if @subdomain.enable_categories;         default_category_id = @subdomain.default_category_id
        elsif @subdomain_pool.enable_categories; default_category_id = @subdomain_pool.default_category_id; end

        @category = Category.where(id: default_category_id).first
        categories =
          if params[:categories].blank? || params[:categories].empty?
            [default_category_id || @category.id]
          else
            params[:categories] if params[:categories].in? category_ids
          end
        @childrens = Category.where(parent_id: @category.id).where(id: category_ids)

        @tags = Tag.where(infilters: true)
        @vidy = Category.vidy
        limit = 30
        page = params[:page] ? params[:page].to_i : 0

        # @items = Product.get_catalog(@subdomain, @subdomain_pool, categories, params[:tags], min_price, max_price, params[:sort_by])
        # @need_pagination = @items.count > limit
        # @items = @items.drop(limit * page).take(limit)

        @items, @need_pagination = get_items(categories, params[:tags], min_price, max_price, params[:sort_by], limit, page)

        render 'subdomain', layout: 'catalog'
      else
        # @category = Category.find(55)
        @category = Category.find(118)
        error 404 if @category.blank?

        @tags = Tag.where(infilters: true)
        @vidy = Category.vidy
        limit = 30
        page = params[:page] ? params[:page].to_i : 0
        categories =
          if params[:categories].blank? || params[:categories].empty?
            if (params[:tags].blank? || params[:tags].empty?) && params[:min_price].blank? && params[:max_price].blank?
              [@category.id] #.concat Category.where(parent_id: (@category.id == 118 ? 55 : @category.id) ).select('id').map(&:id)
            else
              [@category.id, 55, 63, 64, 65] #.concat Category.where(parent_id: (@category.id == 118 ? 55 : @category.id) ).select('id').map(&:id)
            end
          else
            params[:categories]
          end

        # @items = Product.get_catalog(@subdomain, @subdomain_pool, categories, params[:tags], min_price, max_price, params[:sort_by])
        # @need_pagination = @items.count > limit
        # @items = @items.drop(limit * page).take(limit)

        @items, @need_pagination = get_items(categories, params[:tags], min_price, max_price, params[:sort_by], limit, page)

        @childrens = Category.where(parent_id: @category.id)
        temp = @category.template.blank? ? 'index' : @category.template
        render 'category/' + temp , layout: 'catalog'
      end
    end

    get :define_default_categories do
      content_type :json
      excluded_categories = [745, 118, 746]
      category_counts = CategoriesProducts.group(:category_id).count # Подсчитываем, сколько продуктов связано с каждой категорией
      result = CategoriesProducts.group(:product_id).pluck(:product_id).uniq.each_with_object({}) do |product_id, memo| # Ищем для каждого продукта категорию с максимальным количеством связей
        categories_for_product = CategoriesProducts.where(product_id: product_id).pluck(:category_id) # Получаем все категории, связанные с данным продуктом
        filtered_categories = categories_for_product - excluded_categories # Исключаем категории, которые нужно пропустить
        best_category = filtered_categories.max_by { |category_id| category_counts[category_id] || 0 } # Выбираем категорию с максимальным количеством связей
        product = Product.where(id: product_id.to_i).first
        if product && best_category
          memo[product_id] = best_category
          product.category = best_category.to_i
          product.save
        end
      end
      # result = []; CategoriesProducts.where(product_id: 3252).each { |x| result.append([x.category_id, CategoriesProducts.where(category_id: x.category_id).count]) }
      result.to_json
    end

    # custom SimpleNavigation renderer for render items as bootstrap responsive columns
    # TODO: move me in a library

    class BootstrapGridRenderer < SimpleNavigation::Renderer::Base
      def render(item_container)
        if skip_if_empty? && item_container.empty?
          ''
        else
          after = "<div class='col-md-1 col-lg-2 col-sm-2 col-xs-2 hidden-md hidden-sm hidden-xs menu_item first'></div>"
          before = "<div class='col-md-1 col-lg-1 col-sm-2 col-xs-2 hidden-sm hidden-xs menu_item last'></div>"
          content = list_content(item_container)
          content_tag(:div, after+content+before, (item_container.dom_attributes.merge class: "row"))
        end
      end

      private

      def list_content(item_container)
        item_container.items.map { |item|
          tag_options = item.html_options.except(:link)
          tag_options[:class] = "col-md-1 col-sm-2 col-xs-2 menu_item real_item"
          tag_options[:class] += " w110" if (item.name =~ /компании/)
          tag_options[:class] += " w190" if (item.name =~ /информация/)
          tag_options[:class] += " w110" if (item.name =~ /Предоплата/)
          tag_content = tag_for(item)
          if include_sub_navigation?(item)
            tag_content << render_sub_navigation_for(item)
          end
          content_tag(:div, tag_content, tag_options)
        }.join
      end
    end

    SimpleNavigation.register_renderer(bootstrap_grid: BootstrapGridRenderer)

    # i don't know why render_navigation escaping output too strange
    # answer: https://github.com/codeplant/simple-navigation/issues/125
    def cleannav(str)
      return str.gsub('&quot;', '"').gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;quot;', '"').gsub('&amp;lt;', '<').gsub('&amp;gt;', '>')
    end

    def sitenav
      return cleannav(render_navigation(renderer: :bootstrap_grid))
    end

    def catalognav
      return cleannav(render_navigation(:context => :catalog))
    end

    # images list for redactor [{ "thumb": "/img/1m.jpg", "image": "/img/1.jpg" }]
    get "/uploads/imageslist.json" do
      # puts "get /uploads/imageslist.json"
      udir = File.join(Padrino.root, "public")
      dir = File.join(udir, "/uploads/**/*")
      #dir = File.join(udir, "/uploads/*/*")
      imgs = Dir[dir].reject {|fn| (File.directory?(fn) or fn.include? "product" or fn.include? "slide") }
      files = []
      imgs.each do |img|
        f = img[udir.size..-1]
        h = {:thumb => f, :image => f}
        files.push h
      end

      files.to_json
    end

    get "/uploads/imageslist-abs.json" do
      # puts "get /uploads/imageslist-abs.json"
      udir = File.join(Padrino.root, "public")
      dir = File.join(udir, "/uploads/**/*")
      imgs = Dir[dir].reject {|fn| (File.directory?(fn) or fn.include? "product" or fn.include? "slide") }
      files = []
      imgs.each do |img|
        f = img[udir.size..-1]
        h = {:thumb => request.base_url + f, :image => request.base_url + f}
        files.push h
      end
      files.to_json
    end

    get "/search" do
      # puts "get /search"
      #where("title like ? or author like ?", q, q)
      #@results = Category.where("title like ?", "%цветы%").all
      @query = strip_tags(params[:query]).mb_chars.downcase
      if @query.length <= 3
        @error = 'Минимальный поисковый запрос — 3 символа.'
        @pages = []
        @news = []
        @articles = []
        @comments = []
        @products = []
      else
        @pages = Page.where("lower(title) like ? or lower(body) like ?", "%#{@query}%", "%#{@query}%").all
        @news = News.where("lower(title) like ? or lower(body) like ?", "%#{@query}%", "%#{@query}%").all
        @articles = Article.where("lower(title) like ? or lower(body) like ?", "%#{@query}%", "%#{@query}%").all
        @comments = Comment.where("lower(body) like ?", "%#{@query}%").all
        @products = []
        @all_cats.each do |c|
          @products += c.products.where("lower(header) like ? or lower(announce) like ? or lower(text) like ?", "%#{@query}%", "%#{@query}%", "%#{@query}%")
        end

        #@products = Product.find(:all, :conditions => ["lower(title) like ?", "%#{@query}%"])
      end
      if @pages.empty? && @news.empty? && @articles.empty? && @comments.empty? && @products.empty?
        @error = "По вашему запросу ничего не найдено"
      end
      render "search/results"
    end

    get "/get_delivery_price/:id/" do
      # puts "get /get_delivery_price/:id/ app.rb"
      @obj = Subdomain.find(params[:id])
      erb "#{@obj.price}"
    end

    get "/get_overprice/" do
      # puts 'get overprice app.rb'
      current_date1 = cookies[:overcookie]
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      if current_date1.to_s >= date_begin and current_date1.to_s <= date_end
        @value = 'true'
        ProductComplect.check(value)
      else
        @value = 'false'
        ProductComplect.check(value)
      end
      session[:mdata] = current_date1
      cookies[:overvalue] = @value
      erb "#{@value}"
    end

    #get "/get_overvalue/" do
    #  puts 'get get_overvalue app.rb'
    #  f = 'dd'
      #redirect to '/'
    #end


    get "/get_delivery_price/" do
      # puts "get /get_delivery_price/ app.rb"
      @obj = Subdomain.find(@subdomain.id)
      erb "#{@obj.price}"
    end

    get '/get_cities.json' do
      # puts "get /get_cities.json app.rb"
      return Subdomain.where('city LIKE ?', "%#{params[:term]}%").select('city, suffix, url').to_json
    end

    get '/cities.json' do
      content_type :json
      # return Subdomain.where('city LIKE ?', "%#{params[:term]}%").to_json
      begin;  return Subdomain.where('city LIKE ?', "%#{params[:term]}%").select(:city, :suffix, :url).to_json
      rescue; return Subdomain.where('city LIKE ?', "%#{params[:term]}%").select('city, suffix, url').to_json; end
    end

    get '/:page.html' do
      # puts "get /:page.html app.rb"
      redirect_to_root_domain_if_has_geo_subdomain

      page = Page.find_by_uri('index')
      set_seo_tags_for_page(page)

      @subdomain = Subdomain.find_by_url("#{params[:page]}.html")
      session[:subdomain] = @subdomain.id if @subdomain
      @catlist = fetch_categories

      if @subdomain.enable_categories || @subdomain_pool.enable_categories

        if @subdomain.enable_categories
          category_ids = @all_cats.pluck(:id)
          @category = Category.where(id: @subdomain.default_category_id).first

          categories =
            if params[:categories].blank? || params[:categories].empty?
              [@subdomain.default_category_id || @category.id]
            else
              params[:categories] if params[:categories].in? category_ids
            end
          @childrens = Category.where(parent_id: @category.id).where(id: @all_cats.pluck(:id))

        elsif @subdomain_pool.enable_categories
          category_ids = @all_cats.pluck(:id)
          @category = Category.where(id: @subdomain_pool.default_category_id).first

          categories =
            if params[:categories].blank? || params[:categories].empty?
              [@subdomain_pool.default_category_id || @category.id]
            else
              params[:categories] if params[:categories].in? category_ids
            end

          @childrens = Category.where(parent_id: @category.id).where(id: @all_cats.pluck(:id))

        else
          @category = Category.find(55)

          error 404 if @category.blank?
          @category = Category.find(118)

          categories =
            if params[:categories].blank? || params[:categories].empty?
              if (params[:tags].blank? || params[:tags].empty?) && params[:min_price].blank? && params[:max_price].blank?
                [@category.id]
              else
                [@category.id, 55, 63, 64, 65]
              end
            else
              params[:categories]
            end

          @childrens = Category.where(parent_id: @category.id)
        end

        @tags = Tag.where(infilters: true)
        @vidy = Category.vidy
        limit = 30
        page = params[:page] ? params[:page].to_i : 0

        min_price = params[:min_price].blank? ? 0 : params[:min_price].to_i
        max_price = params[:max_price].blank? ? 1_000_000 : params[:max_price].to_i

        @items = Product.get_catalog(
          @subdomain,
          @subdomain_pool,
          categories,
          params[:tags],
          min_price,
          max_price,
          params[:sort_by],
        )

        @need_pagination = @items.count > limit
        @items = @items.drop(limit * page).take(limit)
        render 'subdomain', layout: 'catalog'
      else
        not_found
      end
    end

    get '/:country/:page.html' do
      # puts "get /:country/:page.html app.rb"
      redirect_to_root_domain_if_has_geo_subdomain

      page = Page.find_by_uri('index')
      set_seo_tags_for_page(page)

      @subdomain = Subdomain.find_by_url("#{params[:country]}/#{params[:page]}.html")
      session[:subdomain] = @subdomain.id if @subdomain

      @catlist = fetch_categories

      if @subdomain.enable_categories || @subdomain_pool.enable_categories

        if @subdomain.enable_categories
          category_ids = @all_cats.pluck(:id)
          @category = Category.where(id: @subdomain.default_category_id).first

          categories =
            if params[:categories].blank? || params[:categories].empty?
              [@subdomain.default_category_id || @category.id]
            else
              params[:categories] if params[:categories].in? category_ids
            end

          @childrens = Category.where(parent_id: @category.id).where(id: @all_cats.pluck(:id))

        elsif @subdomain_pool.enable_categories
          category_ids = @all_cats.pluck(:id)
          @category = Category.where(id: @subdomain_pool.default_category_id).first

          categories =
            if params[:categories].blank? || params[:categories].empty?
              [@subdomain_pool.default_category_id || @category.id]
            else
              params[:categories] if params[:categories].in? category_ids
            end

          @childrens = Category.where(parent_id: @category.id).where(id: @all_cats.pluck(:id))

        else
          @category = Category.find(55)

          error 404 if @category.blank?
          @category = Category.find(118)

          categories =
            if params[:categories].blank? || params[:categories].empty?
              if (params[:tags].blank? || params[:tags].empty?) && params[:min_price].blank? && params[:max_price].blank?
                [@category.id]
              else
                [@category.id, 55, 63, 64, 65]
              end
            else
              params[:categories]
            end

          @childrens = Category.where(parent_id: @category.id)
        end

        @tags = Tag.where(infilters: true)
        @vidy = Category.vidy
        limit = 30
        page = params[:page] ? params[:page].to_i : 0

        min_price = params[:min_price].blank? ? 0 : params[:min_price].to_i
        max_price = params[:max_price].blank? ? 1_000_000 : params[:max_price].to_i

        @items = Product.get_catalog(
          @subdomain,
          @subdomain_pool,
          categories,
          params[:tags],
          min_price,
          max_price,
          params[:sort_by],
        )

        @need_pagination = @items.count > limit
        @items = @items.drop(limit * page).take(limit)
        render 'subdomain', layout: 'catalog'
      else

        not_found
      end
    end

    post :index1 do
      # puts "post :index1 do app.rb"

      if request.session[:mdata].nil?
        current_date = '2018-03-09'
        session[:mdata] = '2018-03-09'
      else
        current_date = request.session[:mdata]
      end
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      if current_date.to_s >= date_begin and current_date.to_s <= date_end
        value = 'true'
        ProductComplect.check(value)
      else
        value = 'false'
        ProductComplect.check(value)
        #@change = ProductComplect.new()
        #@change.check(value)
      end

      @curr_date = Overprice.create(
        date: params[:name]
      )
      session[:mdata] = params[:name]

      redirect(url('/'))
    end

    not_found do
      render "404"
    end

    # Authentication helpers for user return URL management
    helpers do
      # Get current authenticated user account
      def current_account
        return @current_account if defined?(@current_account)
        @current_account = session[:user_id] ? UserAccount.find(session[:user_id]) : nil
      rescue ActiveRecord::RecordNotFound
        session[:user_id] = nil
        @current_account = nil
      end

      # Set current authenticated user account
      def set_current_account(user_account)
        @current_account = user_account
        session[:user_id] = user_account ? user_account.id : nil
      end

      # Store the location user came from before authentication
      def store_location(location = nil)
        location ||= request.fullpath
        
        # Don't store auth-related pages or API endpoints
        excluded_paths = ['/sessions/new', '/sessions/create', '/sessions/destroy', 
                         '/user_accounts/new', '/user_accounts/create']
        return if excluded_paths.include?(location)
        return if location.start_with?('/api/', '/admin/')
        return if location.include?('?') && location.match?(/password|token|secret/i)
        
        # Only store if it's a reasonable URL (not too long)
        return if location.length > 2048
        
        session[:return_to] = location
        session[:return_to_time] = Time.now.to_i
      end

      # Redirect back to stored location or default
      def redirect_back_or_default(default = '/')
        stored_location = session[:return_to]
        stored_time = session[:return_to_time]
        
        # Clear stored location
        session.delete(:return_to)
        session.delete(:return_to_time)
        
        # Check if stored location is still valid (not older than 1 hour)
        if stored_location && stored_time && (Time.now.to_i - stored_time) < 3600
          redirect_location = safe_return_url(stored_location, default)
        else
          redirect_location = default
        end
        
        redirect redirect_location
      end

      # Clear stored return location
      def clear_stored_location
        session.delete(:return_to)
      end

      # Require authentication with automatic location storage
      def require_authentication(context = 'profile_access')
        unless current_account
          set_auth_context(context)
          store_location
          redirect url(:sessions, :new)
        end
      end

      # Get smart default redirect based on context
      def smart_default_redirect
        case session[:auth_context]
        when 'checkout'
          '/cart/checkout'
        when 'cart'
          '/cart'
        when 'profile_access'
          url(:user_accounts, :profile)
        else
          '/'
        end
      end

      # Set authentication context for smart redirects
      def set_auth_context(context)
        session[:auth_context] = context
      end

      # Clear authentication context
      def clear_auth_context
        session.delete(:auth_context)
      end

      # Validate return URL to prevent open redirects
      def safe_return_url(url, default = '/')
        return default if url.blank?
        
        # Only allow relative URLs or URLs from same domain
        uri = URI.parse(url)
        if uri.relative?
          url
        elsif uri.host.nil? || uri.host == request.host
          uri.path
        else
          default
        end
      rescue URI::InvalidURIError
        default
      end
      
      # Check if URL is a user account / profile page that requires authentication
      def private_area_url?(url)
        return false if url.blank?
        
        private_paths = [
          '/user_accounts/profile',
          '/user_accounts/edit_profile',
          '/user_accounts/payment'
        ]
        
        # Check exact matches first
        return true if private_paths.any? { |path| url.start_with?(path) }
        
        # Check patterns (using match for Ruby compatibility)
        return true if url =~ /^\/user_accounts\/profile/
        return true if url =~ /^\/user_accounts\/edit/
        return true if url =~ /^\/user_accounts\/payment/
        
        false
      end
      
      # Store the original page user came from before entering private area
      def store_original_page(url = nil)
        url ||= request.referer
        return if url.blank?
        
        begin
          uri = URI.parse(url)
          # Only store if it's from our domain and not a private area itself
          if uri.relative? || (uri.host.nil? || uri.host == request.host)
            original_path = uri.relative? ? url : uri.path
            # Don't store private area URLs as original pages
            unless private_area_url?(original_path) || original_path.start_with?('/sessions/')
              session[:original_page] = original_path
              session[:original_page_time] = Time.now.to_i
            end
          end
        rescue URI::InvalidURIError
          # Ignore invalid URLs
        end
      end
      
      # Get the original page user came from before entering private area
      def get_original_page
        original_page = session[:original_page]
        original_time = session[:original_page_time]
        
        # Check if stored page is still valid (not older than 1 hour)
        if original_page && original_time && (Time.now.to_i - original_time) < 3600
          original_page
        else
          nil
        end
      end
      
      # Clear stored original page
      def clear_original_page
        session.delete(:original_page)
        session.delete(:original_page_time)
      end
    end

  end
end

class Overdateusers < ActiveRecord::Base; end
class Subscribers < ActiveRecord::Base; end


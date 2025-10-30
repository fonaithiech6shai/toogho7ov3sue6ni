# encoding: utf-8
module Rozario
  class Admin < Padrino::Application
    puts 'WTF?'
    use ActiveRecord::ConnectionAdapters::ConnectionManagement
    
    # Хелпер для форматирования даты в русском формате
    def format_russian_date(date_string)
      return nil if date_string.nil? || date_string == ''
      
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
      puts "DEBUG: Начало auto_fill_date_from_order: order_id=#{order_eight_digit_id.inspect}, current_date=#{current_date.inspect}"
      
      # Если дата уже заполнена, не перезаписываем
      if current_date && current_date.to_s.strip != ''
        puts "DEBUG: Дата уже заполнена, оставляем как есть"
        return current_date
      end
      
      if order_eight_digit_id.nil? || order_eight_digit_id.to_s.strip == ''
        puts "DEBUG: order_eight_digit_id пустой, возвращаем nil"
        return nil
      end
      
      begin
        puts "DEBUG: Поиск заказа по eight_digit_id: #{order_eight_digit_id.to_i}"
        order = Order.find_by_eight_digit_id(order_eight_digit_id.to_i)
        
        if order.nil?
          puts "DEBUG: Заказ не найден"
          return nil
        end
        
        puts "DEBUG: Заказ найден, id=#{order.id}"
        
        # Получаем d2_date из заказа
        d2_date = order.d2_date
        puts "DEBUG: d2_date из заказа: #{d2_date.inspect} (#{d2_date.class})"
        
        if d2_date.nil? || d2_date.to_s.strip == ''
          puts "DEBUG: d2_date пустое, возвращаем nil"
          return nil
        end
        
        # Форматируем дату в русский формат
        formatted_date = format_russian_date(d2_date)
        puts "DEBUG: Отформатированная дата: #{formatted_date.inspect}"
        
        return formatted_date
      rescue => e
        puts "ОШИБКА получения даты заказа #{order_eight_digit_id}: #{e.message}"
        puts e.backtrace.first(3).join("\n") if e.backtrace
        return nil
      end
    end
    # TODO: Remove when upgrading to Padrino >= 0.12.0 (has built-in MethodOverride support)
    use Rack::MethodOverride  # Add support for DELETE/PUT methods via forms for Padrino 0.11.1
    register Padrino::Rendering
    register Padrino::Mailer
    register Padrino::Helpers
    register Padrino::Admin::AccessControl

    # ##
    # # Application configuration options
    # #
    # # set :raise_errors, true         # Raise exceptions (will stop application) (default for test)
    # # set :dump_errors, true          # Exception backtraces are written to STDERR (default for production/development)
    # # set :show_exceptions, true      # Shows a stack trace in browser (default for development)
    # # set :logging, true              # Logging in STDOUT for development and file for production (default only for development)
    # set :public_folder, "/www"   # Location for static assets (default root/public)
    # # set :reload, false              # Reload application files (default in development)
    # # set :default_builder, "foo"     # Set a custom form builder (default 'StandardFormBuilder')
    # # set :locale_path, "bar"         # Set path for I18n translations (default your_app/locales)
    # # disable :sessions               # Disabled sessions by default (enable if needed)
    # # disable :flash                  # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
    # # layout  :my_layout              # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
    # #

    # set :admin_model, 'Account'
    # set :login_page,  '/admin/sessions/new'

    # set :protection, false
    # #set :protect_from_csrf, false
    # #set :allow_disabled_csrf, true

    # enable :sessions
    # enable :authentication
    # disable :store_location

    # access_control.roles_for :any do |role|
    #   role.protect '/'
    #   role.allow   '/sessions'
    # end

    # access_control.roles_for :admin do |role|
    #   role.project_module :menus_on_main,  '/menus_on_main'
    #   role.project_module :discounts,      '/discounts'
    #   role.project_module :delivery,       '/delivery'
    #   role.project_module :regions,        '/regions'
    #   role.project_module :categorygroups, '/categorygroups'
    #   role.project_module :complects,      '/complects'
    #   role.project_module :pages,          '/pages'
    #   role.project_module :categories,     '/categories'
    #   role.project_module :products,       '/products'
    #   role.project_module :news,           '/news'
    #   role.project_module :articles,       '/articles'
    #   role.project_module :photos,         '/photos'
    #   role.project_module :albums,         '/albums'
    #   role.project_module :comments,       '/comments'
    #   role.project_module :contacts,       '/contacts'
    #   # role.project_module :options,        '/options'
    #   role.project_module :clients,        '/clients'
    #   role.project_module :accounts,       '/accounts'
    #   role.project_module :seo,            '/seo'
    #   role.project_module :smiles,         '/smiles'
    #   role.project_module :disabled_dates, '/disabled_dates'
    #   role.project_module :payment,        '/payment'
    # end

    # # Custom error management
    # error(403) { @title = "Error 403"; render('errors/403', :layout => :error) }
    # error(404) { @title = "Error 404"; render('errors/404', :layout => :error) }
    # error(500) { @title = "Error 500"; render('errors/500', :layout => :error) }
  end
end

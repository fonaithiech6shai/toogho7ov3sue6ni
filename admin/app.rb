# encoding: utf-8
module Rozario
  class Admin < Padrino::Application
    puts 'WTF?'
    use ActiveRecord::ConnectionAdapters::ConnectionManagement
    
    # Глобальная обработка ошибок кодировки
    error Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError, Encoding::CompatibilityError do
      logger.error "Encoding error: #{env['REQUEST_PATH']} - #{request.env['REQUEST_METHOD']}" if defined?(logger)
      
      # Перенаправляем на безопасную версию страницы
      if request.path_info.include?('permissions')
        @encoding_error_message = "Ошибка кодировки в данных. Некоторые поля могут отображаться некорректно."
        @accounts = []
        @modules = Account::AVAILABLE_MODULES rescue []
        @title = "Управление правами (ошибка кодировки)"
        render 'permissions/safe_index'
      else
        # Для других страниц - показываем общую ошибку
        erb '<h1>Ошибка кодировки</h1><p>Возникла проблема с кодировкой данных. Обратитесь к администратору.</p>'
      end
    end
    
    # Хелпер для форматирования даты в русском формате
    def format_russian_date(date_string)
      return nil if date_string.nil? || date_string == ''
      
      begin
        if date_string.is_a?(String)
          if date_string.include?('/')
            parsed_date = Date.strptime(date_string, '%d/%m/%Y')
          else
            parsed_date = Date.parse(date_string)
          end
        else
          parsed_date = date_string.to_date
        end
        
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
        logger.warn "Error formatting date #{date_string}: #{e.message}" if respond_to?(:logger)
        return nil
      end
    end
    
    # Хелпер для автоматического заполнения даты из заказа
    def auto_fill_date_from_order(order_eight_digit_id, current_date = nil)
      return current_date if current_date && current_date.to_s.strip != ''
      return nil if order_eight_digit_id.nil? || order_eight_digit_id.to_s.strip == ''
      
      begin
        order = Order.find_by_eight_digit_id(order_eight_digit_id.to_i)
        return nil unless order
        
        d2_date = order.d2_date
        return nil if d2_date.nil? || d2_date.to_s.strip == ''
        
        format_russian_date(d2_date)
      rescue => e
        logger.warn "Error getting order date for #{order_eight_digit_id}: #{e.message}" if respond_to?(:logger)
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

    set :admin_model, 'Account'
    set :login_page,  '/admin/sessions/new'

    set :protection, false
    #set :protect_from_csrf, false
    #set :allow_disabled_csrf, true

    enable :sessions
    enable :authentication
    disable :store_location

    # Базовая защита для всех пользователей
    access_control.roles_for :any do |role|
      role.protect '/'
      role.allow   '/sessions'
    end

    # Динамические права на основе permissions пользователя
    access_control.roles_for :admin, :manager, :editor do |role, user|
      if user && user.role == 'admin'
        # Админы имеют доступ ко всем модулям
        Account::AVAILABLE_MODULES.each do |mod|
          role.project_module mod.to_sym, "/#{mod}"
        end
        role.project_module :permissions, '/permissions' # Управление правами только для админов
      elsif user
        # Остальные пользователи - только к разрешенным модулям
        user.permissions.each do |perm|
          role.project_module perm.to_sym, "/#{perm}"
        end
        # Доступ к управлению правами только если есть права на accounts
        if user.has_permission?('accounts')
          role.project_module :permissions, '/permissions'
        end
      end
    end

    # # Custom error management
    # error(403) { @title = "Error 403"; render('errors/403', :layout => :error) }
    # error(404) { @title = "Error 404"; render('errors/404', :layout => :error) }
    # error(500) { @title = "Error 500"; render('errors/500', :layout => :error) }
  end
end

# encoding: utf-8
require 'ostruct'
require 'json'

Rozario::Admin.controllers :permissions do
  
  # Список всех пользователей с их правами
  get :index do
    @title = "Управление правами"
    
    # Получаем аккаунты и безопасно обрабатываем их данные
    begin
      # Сначала пробуем загрузить через обычные ActiveRecord методы
      @accounts = Account.order('id desc').limit(50) # Ограничиваем для безопасности
      
      # Проверяем каждый аккаунт отдельно
      @accounts = @accounts.map do |account|
        begin
          # Проверяем, можем ли мы безопасно обратиться к display_name
          test_display = account.display_name
          account # Если ок - возвращаем исходный
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
          # Если проблема с кодировкой - обрабатываем
          safe_encode_account(account)
        end
      end
      
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => encoding_error
      # Ошибка кодировки - пробуем загрузить через raw SQL
      begin
        @accounts = load_accounts_via_sql
      rescue => sql_error
        logger.error "Failed to load via SQL: #{sql_error.message}" if defined?(logger)
        @accounts = []
        @encoding_error = "Ошибка кодировки: #{encoding_error.message}"
      end
    rescue => e
      # Любая другая ошибка
      logger.error "Error loading accounts: #{e.message}" if defined?(logger)
      @accounts = []
      @encoding_error = e.message
    end
    
    @modules = Account::AVAILABLE_MODULES
    render 'permissions/index'
  end
  
  private
  
  # Безопасное кодирование данных аккаунта
  def safe_encode_account(account)
    # Обрабатываем строковые поля
    ['name', 'surname', 'email'].each do |field|
      value = account.send(field)
      if value && value.is_a?(String)
        account.send("#{field}=", safe_string_convert(value))
      end
    end
    
    account
  rescue => e
    # Если не можем обработать - создаём fallback
    fallback_account = OpenStruct.new(
      id: account.id || 0,
      name: "[Ошибка кодировки]",
      surname: "",
      email: "error@example.com",
      role: account.role || 'editor',
      permissions: [],
      display_name: "[Ошибка кодировки]"
    )
    
    # Добавляем методы, которые использует шаблон
    fallback_account.define_singleton_method(:has_permission?) { |mod| false }
    fallback_account.define_singleton_method(:add_permission) { |mod| false }
    fallback_account.define_singleton_method(:remove_permission) { |mod| false }
    fallback_account.define_singleton_method(:save) { false }
    
    fallback_account
  end
  
  # Безопасное преобразование строки
  def safe_string_convert(str)
    return str if str.nil? || str.empty?
    return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?
    
    begin
      # Пробуем Windows-1251 -> UTF-8
      str.dup.force_encoding('Windows-1251').encode('UTF-8', 
        invalid: :replace, undef: :replace, replace: '?')
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      # Последняя попытка
      str.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    rescue => e
      "[Ошибка кодировки]"
    end
  end
  
  # Загрузка аккаунтов через raw SQL в критических ситуациях
  def load_accounts_via_sql
    connection = ActiveRecord::Base.connection
    
    # Простой SQL-запрос без ActiveRecord
    sql = "SELECT id, COALESCE(name, '') as name, COALESCE(surname, '') as surname, COALESCE(email, '') as email, COALESCE(role, 'editor') as role, COALESCE(role_permissions, '[]') as role_permissions FROM accounts ORDER BY id DESC LIMIT 50"
    
    results = connection.execute(sql)
    
    accounts = []
    results.each do |row|
      begin
        # Создаём объект-заглушку с безопасными данными
        account_data = OpenStruct.new(
          id: row[0].to_i,
          name: safe_string_convert(row[1].to_s),
          surname: safe_string_convert(row[2].to_s), 
          email: safe_string_convert(row[3].to_s),
          role: safe_string_convert(row[4].to_s),
          role_permissions: row[5].to_s
        )
        
        # Добавляем методы, которые ожидает шаблон
        account_data.define_singleton_method(:display_name) do
          full_name = [name, surname].reject(&:empty?).join(' ').strip
          full_name.empty? ? email : full_name
        end
        
        account_data.define_singleton_method(:permissions) do
          begin
            JSON.parse(role_permissions)
          rescue
            []
          end
        end
        
        account_data.define_singleton_method(:has_permission?) { |mod| role == 'admin' || permissions.include?(mod.to_s) }
        account_data.define_singleton_method(:add_permission) { |mod| false } # Отключаем в безопасном режиме
        account_data.define_singleton_method(:remove_permission) { |mod| false }
        account_data.define_singleton_method(:save) { false }
        
        accounts << account_data
        
      rescue => row_error
        # Если не можем обработать строку - пропускаем
        logger.error "Error processing row: #{row_error.message}" if defined?(logger)
      end
    end
    
    accounts
  end
  
  # Форма редактирования прав пользователя
  get :edit, :with => :id do
    @title = "Редактировать права"
    @account = Account.find(params[:id])
    @modules = Account::AVAILABLE_MODULES
    @current_permissions = @account.permissions
    render 'permissions/edit'
  end
  
  # Сохранение изменений прав
  put :update, :with => :id do
    @account = Account.find(params[:id])
    
    # Получаем выбранные модули из параметров
    selected_modules = params[:permissions] || []
    
    # Фильтруем только доступные модули
    valid_modules = selected_modules.select { |m| Account::AVAILABLE_MODULES.include?(m) }
    
    @account.permissions = valid_modules
    
    if @account.save
      flash[:success] = "Права пользователя #{@account.display_name} успешно обновлены"
      redirect url(:permissions, :index)
    else
      flash[:error] = "Ошибка при сохранении прав"
      @modules = Account::AVAILABLE_MODULES
      @current_permissions = @account.permissions
      render 'permissions/edit'
    end
  end
  
  # Быстрое переключение прав через AJAX
  post :toggle, :with => :id do
    @account = Account.find(params[:id])
    module_name = params[:module]
    
    if Account::AVAILABLE_MODULES.include?(module_name)
      if @account.has_permission?(module_name)
        @account.remove_permission(module_name)
        action = 'removed'
      else
        @account.add_permission(module_name)
        action = 'added'
      end
      
      if @account.save
        content_type :json
        { success: true, action: action, has_permission: @account.has_permission?(module_name) }.to_json
      else
        content_type :json
        { success: false, error: 'Ошибка при сохранении' }.to_json
      end
    else
      content_type :json
      { success: false, error: 'Недопустимый модуль' }.to_json
    end
  end
  
  # Массовое назначение прав
  post :bulk_update do
    account_ids = params[:account_ids].to_s.split(',').map(&:to_i)
    selected_modules = params[:permissions] || []
    
    valid_modules = selected_modules.select { |m| Account::AVAILABLE_MODULES.include?(m) }
    
    updated_count = 0
    account_ids.each do |account_id|
      account = Account.find_by_id(account_id)
      if account && account.role != 'admin' # Не изменяем права админов
        account.permissions = valid_modules
        if account.save
          updated_count += 1
        end
      end
    end
    
    flash[:success] = "Права обновлены для #{updated_count} пользователей"
    redirect url(:permissions, :index)
  end
  
end

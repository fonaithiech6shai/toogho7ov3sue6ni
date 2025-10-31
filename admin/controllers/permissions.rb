# encoding: utf-8
require 'ostruct'
require 'json'

Rozario::Admin.controllers :permissions do
  
  # Список всех пользователей с их правами
  get :index do
    @title = "Управление правами"
    
    # Принудительно используем только безопасную загрузку через SQL
    begin
      @accounts = load_accounts_via_sql
      @modules = Account::AVAILABLE_MODULES
      
      # Проверяем, можем ли мы рендерить шаблон
      test_render = erb '<%= @title %>'
      
      render 'permissions/index'
      
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError, Encoding::CompatibilityError => encoding_error
      # Любая ошибка кодировки - перенаправляем на безопасную страницу
      @encoding_error = "Ошибка кодировки: #{encoding_error.class.name} - #{encoding_error.message}"
      @accounts = []
      @modules = []
      
      erb '<h1>Ошибка кодировки</h1><p><%= @encoding_error %></p><p><a href="/admin">На главную</a></p>'
      
    rescue => e
      # Любая другая ошибка
      @error_message = e.message
      @error_class = e.class.name
      
      erb '<h1>Ошибка</h1><p><%= @error_class %>: <%= @error_message %></p><p><a href="/admin">На главную</a></p>'
    end
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
  
  # Максимально безопасная загрузка аккаунтов
  def load_accounts_via_sql
    begin
      connection = ActiveRecord::Base.connection
      
      # Принудительно устанавливаем кодировку для соединения
      connection.execute("SET NAMES utf8") rescue nil
      connection.execute("SET CHARACTER SET utf8") rescue nil
      
      # Используем CONVERT для принудительного преобразования в UTF-8
      sql = "
        SELECT 
          id,
          CONVERT(COALESCE(name, '') USING utf8) as name,
          CONVERT(COALESCE(surname, '') USING utf8) as surname, 
          CONVERT(COALESCE(email, '') USING utf8) as email,
          CONVERT(COALESCE(role, 'editor') USING utf8) as role,
          CONVERT(COALESCE(role_permissions, '[]') USING utf8) as role_permissions
        FROM accounts 
        ORDER BY id DESC 
        LIMIT 20
      "
      
      results = connection.execute(sql)
      accounts = []
      
      results.each_with_index do |row, index|
        begin
          # Преобразуем каждое поле в безопасную UTF-8 строку
          safe_id = row[0].to_i rescue 0
          safe_name = ultra_safe_string(row[1])
          safe_surname = ultra_safe_string(row[2])
          safe_email = ultra_safe_string(row[3])
          safe_role = ultra_safe_string(row[4])
          safe_permissions = ultra_safe_string(row[5])
          
          # Проверяем, что все строки в UTF-8
          [safe_name, safe_surname, safe_email, safe_role, safe_permissions].each do |str|
            str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
          end
          
          # Создаём простой Hash вместо OpenStruct
          account_hash = {
            'id' => safe_id,
            'name' => safe_name,
            'surname' => safe_surname,
            'email' => safe_email,
            'role' => safe_role,
            'role_permissions' => safe_permissions
          }
          
          # Преобразуем в OpenStruct только если все ок
          account_data = OpenStruct.new(account_hash)
          
          # Добавляем методы
          add_safe_methods_to_account(account_data)
          
          accounts << account_data
          
        rescue => row_error
          # Создаём fallback-аккаунт
          fallback = create_fallback_account(index + 1)
          accounts << fallback
        end
      end
      
      accounts
      
    rescue => e
      # Если совсем ничего не работает - возвращаем пустой массив
      [create_fallback_account(1, "Ошибка загрузки: #{e.message}")]
    end
  end
  
  # Максимально безопасное преобразование строки
  def ultra_safe_string(value)
    return "" if value.nil?
    
    str = value.to_s
    return str if str.empty?
    
    # Полная очистка строки
    begin
      # Удаляем все не-ASCII символы и заменяем их безопасными
      cleaned = str.encode('UTF-8', 
        invalid: :replace, 
        undef: :replace, 
        replace: '?',
        universal_newline: true
      )
      
      # Удаляем потенциально опасные символы
      cleaned.gsub!(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
      
      cleaned
    rescue => e
      # Последний fallback - только ASCII
      str.gsub(/[^\x20-\x7E]/, '?')
    end
  end
  
  # Создание fallback-аккаунта
  def create_fallback_account(index, error_msg = nil)
    account_data = OpenStruct.new(
      id: index,
      name: "User",
      surname: "#{index}",
      email: "user#{index}@example.com",
      role: "editor",
      role_permissions: "[]"
    )
    
    account_data.define_singleton_method(:display_name) { "User #{index}#{error_msg ? ' (Error)' : ''}" }
    add_safe_methods_to_account(account_data)
    
    account_data
  end
  
  # Добавление методов к аккаунту
  def add_safe_methods_to_account(account_data)
    account_data.define_singleton_method(:permissions) do
      begin
        JSON.parse(role_permissions || '[]')
      rescue
        []
      end
    end
    
    account_data.define_singleton_method(:has_permission?) { |mod| role == 'admin' || permissions.include?(mod.to_s) }
    account_data.define_singleton_method(:add_permission) { |mod| false }
    account_data.define_singleton_method(:remove_permission) { |mod| false }
    account_data.define_singleton_method(:save) { false }
    
    # Добавляем display_name если его нет
    unless account_data.respond_to?(:display_name)
      account_data.define_singleton_method(:display_name) do
        full_name = [name, surname].reject { |s| s.nil? || s.empty? }.join(' ').strip
        full_name.empty? ? email : full_name
      end
    end
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

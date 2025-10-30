# encoding: utf-8
Rozario::Admin.controllers :permissions do
  
  # Список всех пользователей с их правами
  get :index do
    @title = "Управление правами"
    @accounts = Account.order('id desc')
    @modules = Account::AVAILABLE_MODULES
    render 'permissions/index'
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

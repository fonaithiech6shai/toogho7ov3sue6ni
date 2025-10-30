# encoding: utf-8
Rozario::Admin.controllers :base do
  
  # Метод для проверки прав для всех контроллеров
  def check_module_access(module_name)
    unless can_access_module?(module_name)
      flash[:error] = "У вас нет прав доступа к данному разделу"
      halt 403
    end
  end
  
  get :index, :map => "/" do
    @available_modules = accessible_modules_for_menu
    render "base/index"
  end
end

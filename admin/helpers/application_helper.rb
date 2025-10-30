# encoding: utf-8
module Rozario
  class Admin
    module ApplicationHelper
      
      # Проверка прав доступа к модулю
      def can_access_module?(module_name)
        return true unless current_account # Если нет авторизации, пропускаем
        return true if current_account.role == 'admin' # Админы всё могут
        
        current_account.has_permission?(module_name.to_s)
      end
      
      # Проверка прав на редактирование
      def can_edit_module?(module_name)
        can_access_module?(module_name)
      end
      
      # Проверка прав на удаление
      def can_delete_module?(module_name)
        return true if current_account && current_account.role == 'admin'
        # Менеджеры и редакторы могут только смотреть/редактировать
        false
      end
      
      # Проверка прав на управление правами
      def can_manage_permissions?
        return false unless current_account
        current_account.role == 'admin'
      end
      
      # Получить список доступных модулей для меню
      def accessible_modules_for_menu
        return Account::AVAILABLE_MODULES if !current_account || current_account.role == 'admin'
        
        current_account.permissions
      end
      
    end
    
    helpers ApplicationHelper
  end
end

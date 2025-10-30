# encoding: utf-8
module Rozario
  class Admin
    module PermissionsHelper
      
      # Преобразование названий модулей в человекочитаемый вид
      def humanize_module_name(module_name)
        translations = {
          'accounts' => 'Учетные записи',
          'products' => 'Товары',
          'categories' => 'Категории',
          'orders' => 'Заказы',
          'comments' => 'Комментарии',
          'news' => 'Новости',
          'articles' => 'Статьи',
          'pages' => 'Страницы',
          'clients' => 'Клиенты',
          'contacts' => 'Контакты',
          'seo' => 'SEO',
          'payment' => 'Платежи',
          'regions' => 'Регионы',
          'delivery' => 'Доставка',
          'discounts' => 'Скидки',
          'categorygroups' => 'Группы категорий',
          'complects' => 'Комплекты',
          'menus_on_main' => 'Меню на главной',
          'photos' => 'Фотографии',
          'albums' => 'Альбомы',
          'slides' => 'Слайды',
          'slideshows' => 'Слайд-шоу',
          'tags' => 'Теги',
          'disabled_dates' => 'Отключенные даты',
          'general_config' => 'Общая конфигурация',
          'smiles' => 'Отзывы (Смайлы)',
          'seo_texts' => 'SEO тексты'
        }
        
        translations[module_name.to_s] || module_name.to_s.humanize
      end
      
      # Класс для отображения роли
      def role_class(role)
        case role.to_s
        when 'admin'
          'label-important'
        when 'manager' 
          'label-warning'
        when 'editor'
          'label-info'
        else
          'label-default'
        end
      end
      
      # Проверка прав для текущего пользователя
      def current_user_can_manage_permissions?
        return false unless current_account
        current_account.role == 'admin' || current_account.has_permission?('accounts')
      end
      
    end
    
    helpers PermissionsHelper
  end
end

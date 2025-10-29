# Реализация редиректа после logout

## Описание задачи
После выхода через `/sessions/destroy` необходимо возвращать пользователя на исходную страницу, на которой он выбрал выйти из авторизации. Если это личный кабинет (из которого нет доступа неавторизованному пользователю), то как fallback нужно редиректить на главную.

## Реализация

### 1. Добавлена функция определения приватных страниц
В `app/app.rb` добавлена функция `private_area_url?(url)` которая определяет, является ли URL частью личного кабинета:

- `/user_accounts/profile*` - страница профиля
- `/user_accounts/edit_profile*` - редактирование профиля  
- `/user_accounts/payment*` - страница оплаты

### 2. Модификация контроллера sessions
В `app/controllers/sessions.rb` обновлен метод `get :destroy`:

- Извлекается referrer из заголовка HTTP_REFERER
- Проверяется безопасность URL (только наш домен)
- Если это приватная страница → редирект на главную `/`
- Если это публичная страница → возврат на исходную страницу
- При ошибках парсинга → редирект на главную `/`

### 3. Логика редиректа

```ruby
# Извлечение referrer и парсинг
logout_referrer = request.referer
uri = URI.parse(logout_referrer)

# Проверка безопасности (только наш домен)
if uri.relative? || uri.host == CURRENT_DOMAIN
  # Определение типа страницы
  if private_area_url?(uri.path)
    logout_redirect_url = '/'  # Личный кабинет → главная
  else  
    logout_redirect_url = uri.path  # Публичная → исходная
  end
end
```

### 4. Тестирование
Создан комплексный тест `test_logout_redirect_simple.rb` который проверяет:

✅ **Определение приватных страниц**
- Корректно определяет `/user_accounts/*` как приватные
- Корректно определяет публичные страницы

✅ **Логику редиректа**
- Logout из профиля → главная страница `/`
- Logout из категории → исходная страница `/category/roses`
- Logout без referrer → главная страница `/`
- Logout с внешним referrer → главная страница `/` (безопасность)
- Logout из редактирования → главная страница `/`

## Безопасность

- ✅ Проверка домена (только rozarioflowers.ru)
- ✅ Защита от внешних редиректов
- ✅ Обработка ошибок парсинга URL
- ✅ Fallback на главную страницу при любых проблемах

## Совместимость

- ✅ Сохранена поддержка localStorage флага `user_just_logged_out`
- ✅ Не нарушена существующая функциональность
- ✅ Все существующие тесты проходят успешно

## Коммит

```
implement logout redirect to referrer with private area fallback

- add private_area_url? helper to identify user account pages
- modify sessions#destroy to redirect back to referrer when appropriate  
- redirect to home page when logging out from private areas (profile, edit, payment)
- redirect to original page when logging out from public pages
- include security checks to prevent external domain redirects
- maintain backward compatibility with existing localStorage logout flag
```

Реализация успешно протестирована и готова к использованию.
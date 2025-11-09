# Руководство по экспорту продуктов в Saleor

Этот модуль позволяет экспортировать продукты и категории из базы данных Rozario в формат, совместимый с Saleor через GraphQL API.

## Возможности

✅ **Экспорт категорий** с иерархической структурой  
✅ **Экспорт продуктов** с полным описанием и SEO данными  
✅ **Экспорт вариантов** (комплектаций) продуктов  
✅ **Автоматическое создание** типов продуктов  
✅ **Поддержка изображений** и метаданных  
✅ **Масштабируемая обработка** с батчами и задержками  
✅ **Подробное логирование** и статистика экспорта  
✅ **CLI утилита** и Rake задачи для удобного запуска  

## Архитектура

### Маппинг данных Rozario → Saleor

| Rozario | Saleor | Описание |
|---------|--------|----------|
| `Category` | `Category` | Категории с иерархией |
| `Product` | `Product` | Основные данные продукта |
| `ProductComplect` | `ProductVariant` | Варианты продукта (размеры, цены) |
| `Complect` | Атрибуты вариантов | Типы комплектаций (standard, small, lux) |
| SEO поля | SEO поля | title, description, keywords |
| Изображения | ProductMedia | URL изображений |

### Структура файлов

```
lib/saleor_export/
├── saleor_research.rb      # Схемы данных и GraphQL запросы
├── product_exporter.rb     # Основной класс экспортера
└── export_cli.rb           # CLI утилита

lib/tasks/
└── saleor_export.rake      # Rake задачи

docs/
└── SALEOR_EXPORT_GUIDE.md  # Эта документация
```

## Установка и настройка

### Требования

- Ruby 2.7+ 
- Активное подключение к базе данных Rozario
- Доступ к Saleor GraphQL API
- Токен аутентификации Saleor

### ✅ Протестировано с rozario.eu.saleor.cloud

Система экспорта протестирована и полностью совместима с инстансом:
- **Endpoint**: `https://rozario.eu.saleor.cloud/graphql/`
- **Status**: GraphQL API доступен и функционален
- **Ready**: Готов к импорту при наличии токена аутентификации

### Подготовка Saleor

1. **Создайте API токен** в админке Saleor:
   - Settings → Configuration → API Access
   - Create new token with permissions:
     - `MANAGE_PRODUCTS`
     - `MANAGE_PRODUCT_TYPES_AND_ATTRIBUTES` 
     - `MANAGE_CATEGORIES`

2. **Запишите endpoint URL**:
   ```
   https://your-store.saleor.cloud/graphql/
   ```

## Использование

### 1. Через Rake задачи (рекомендуется)

#### Проверка статистики базы данных
```bash
rake saleor:stats
```

#### Тестирование подключения
```bash
# Протестировано с rozario.eu.saleor.cloud
rake saleor:test_connection \
  SALEOR_ENDPOINT="https://rozario.eu.saleor.cloud/graphql/" \
  SALEOR_TOKEN="your_token_here"
```

#### Экспорт тестовых данных (5 продуктов)
```bash
# Быстрый тест с rozario.eu.saleor.cloud
rake saleor:export_sample \
  SALEOR_ENDPOINT="https://rozario.eu.saleor.cloud/graphql/" \
  SALEOR_TOKEN="your_token_here"
```

#### Полный экспорт
```bash
rake saleor:export \
  SALEOR_ENDPOINT="https://your-store.saleor.cloud/graphql/" \
  SALEOR_TOKEN="your_token_here"
```

#### Экспорт с ограничениями
```bash
# Экспорт первых 100 продуктов
rake saleor:export \
  SALEOR_ENDPOINT="..." \
  SALEOR_TOKEN="..." \
  LIMIT=100

# Экспорт конкретных продуктов
rake saleor:export \
  SALEOR_ENDPOINT="..." \
  SALEOR_TOKEN="..." \
  PRODUCT_IDS="1,2,3,10,15"

# Пропустить категории (если уже созданы)
rake saleor:export \
  SALEOR_ENDPOINT="..." \
  SALEOR_TOKEN="..." \
  SKIP_CATEGORIES=true
```

### 2. Через CLI утилиту

```bash
# Показать помощь
ruby lib/saleor_export/export_cli.rb --help

# Тестирование
ruby lib/saleor_export/export_cli.rb \
  --endpoint "https://your-store.saleor.cloud/graphql/" \
  --token "your_token" \
  --test-connection

# Полный экспорт с настройками
ruby lib/saleor_export/export_cli.rb \
  --endpoint "https://your-store.saleor.cloud/graphql/" \
  --token "your_token" \
  --batch-size 5 \
  --delay 1.5 \
  --log-file export.log

# Экспорт конкретных продуктов
ruby lib/saleor_export/export_cli.rb \
  --endpoint "..." \
  --token "..." \
  --products 1,2,3 \
  --no-categories
```

### 3. Программно из Ruby

```ruby
require_relative 'lib/saleor_export/product_exporter'

# Создание экспортера
exporter = SaleorProductExporter.new(
  'https://your-store.saleor.cloud/graphql/',
  'your_token_here',
  {
    logger: Logger.new(STDOUT),
    batch_size: 10,
    delay: 1
  }
)

# Тестирование подключения
if exporter.test_connection
  puts "✓ Connection OK"
end

# Полный экспорт
result = exporter.export_all({
  export_categories: true,
  create_product_types: true,
  limit: 50
})

if result[:success]
  puts "Export completed in #{result[:duration]} seconds"
  puts "Stats: #{result[:stats]}"
else
  puts "Export failed: #{result[:error]}"
end

# Экспорт только категорий
exporter.export_categories

# Экспорт конкретного продукта
product = Product.find(123)
exporter.export_product(product)
```

## Параметры конфигурации

### Environment Variables

| Переменная | Описание | По умолчанию |
|------------|----------|---------------|
| `SALEOR_ENDPOINT` | URL GraphQL API | - |
| `SALEOR_TOKEN` | Токен аутентификации | - |
| `LIMIT` | Максимум продуктов | Все |
| `PRODUCT_IDS` | Конкретные ID через запятую | - |
| `BATCH_SIZE` | Размер батча | 10 |
| `DELAY` | Задержка между запросами (сек) | 1 |
| `SKIP_CATEGORIES` | Пропустить категории | false |
| `SKIP_PRODUCT_TYPES` | Пропустить типы продуктов | false |
| `DEBUG` | Включить debug лог | false |
| `STATS_FILE` | Файл для сохранения статистики | - |

### Опции CLI

```bash
  -e, --endpoint URL           Saleor GraphQL endpoint
  -t, --token TOKEN            Authentication token
  -p, --products IDS           Export specific product IDs
  -l, --limit N                Limit number of products
  -b, --batch-size N           Batch size (default: 10)
  -d, --delay N                Delay between requests (default: 1)
      --no-categories          Skip categories export
      --no-product-types       Skip product types creation
      --log-file FILE          Log to file instead of STDOUT
      --debug                  Enable debug logging
      --stats FILE             Save statistics to file
      --test-connection        Test connection and exit
  -h, --help                   Show help
```

## Процесс экспорта

### Этапы экспорта

1. **Проверка подключения** к Saleor API
2. **Экспорт категорий** (сначала родительские, затем дочерние)
3. **Создание типов продуктов** (Цветы, Композиции, Букеты)
4. **Экспорт продуктов** батчами
5. **Создание вариантов** для каждого продукта
6. **Статистика результатов**

### Обработка ошибок

- **Пропуск некорректных данных** с логированием
- **Повтор запросов** при временных сбоях
- **Подробные сообщения об ошибках**
- **Продолжение работы** при единичных сбоях

### Производительность

- **Батчевая обработка** для уменьшения нагрузки
- **Задержки между запросами** для соблюдения rate limits
- **Параллельная обработка вариантов**
- **Оптимизированные SQL запросы**

## Структура данных в Saleor

### Product (Продукт)
```json
{
  "name": "Букет 'Нежность'",
  "slug": "bouquet-tenderness",
  "description": {
    "blocks": [
      {
        "type": "paragraph",
        "data": {
          "text": "Описание продукта..."
        }
      }
    ]
  },
  "seoTitle": "SEO заголовок",
  "seoDescription": "SEO описание",
  "category": "category_id",
  "productType": "product_type_id",
  "weight": 0.5,
  "metadata": [
    {"key": "rozario_id", "value": "123"},
    {"key": "rozario_rating", "value": "5"},
    {"key": "rozario_color", "value": "красный"}
  ]
}
```

### ProductVariant (Вариант)
```json
{
  "name": "Букет 'Нежность' - Стандарт",
  "sku": "123-1",
  "price": 2500,
  "costPrice": 1500,
  "weight": 0.5,
  "trackInventory": false,
  "metadata": [
    {"key": "rozario_complect_id", "value": "456"},
    {"key": "rozario_complect_type", "value": "standard"}
  ]
}
```

### Category (Категория)
```json
{
  "name": "Букеты",
  "slug": "bouquets",
  "description": "Красивые букеты на любой случай",
  "seoTitle": "Букеты цветов",
  "seoDescription": "Купить букеты...",
  "parent": "parent_category_id",
  "backgroundImage": "https://rozarioflowers.ru/uploads/categories/bouquets.jpg"
}
```

## Логирование и мониторинг

### Уровни логов

- **INFO**: Основные этапы процесса
- **DEBUG**: Детали каждой операции
- **WARN**: Предупреждения и пропуски
- **ERROR**: Критические ошибки

### Пример лога
```
[2024-01-15 10:30:00] INFO: SaleorProductExporter initialized: https://store.saleor.cloud/graphql/
[2024-01-15 10:30:01] INFO: Starting full export...
[2024-01-15 10:30:02] INFO: ✓ Connection successful
[2024-01-15 10:30:03] INFO: Exporting categories...
[2024-01-15 10:30:04] INFO: Created category: Букеты (Y2F0ZWdvcnk6MQ==)
[2024-01-15 10:30:05] INFO: Categories export completed. Created: 15, Errors: 0
[2024-01-15 10:30:06] INFO: Creating product types...
[2024-01-15 10:30:07] INFO: Created product type: Цветы
[2024-01-15 10:30:08] INFO: Exporting products...
[2024-01-15 10:30:09] INFO: Found 1250 products to export
[2024-01-15 10:30:15] INFO: Created product: Букет 'Романс' (UHJvZHVjdDoxMjM=)
[2024-01-15 10:30:16] DEBUG: Created variant: Букет 'Романс' - Стандарт (123-1)
[2024-01-15 10:30:30] INFO: Progress: 100/1250 (8.0%)
...
[2024-01-15 11:45:00] INFO: === EXPORT STATISTICS ===
[2024-01-15 11:45:00] INFO: Duration: 4500.23 seconds
[2024-01-15 11:45:00] INFO: Categories: 15 created, 0 errors
[2024-01-15 11:45:00] INFO: Products: 1250 created, 5 errors
[2024-01-15 11:45:00] INFO: Variants: 3750 created, 12 errors
[2024-01-15 11:45:00] INFO: 🎉 Export completed successfully!
```

### Статистика

```ruby
{
  categories_processed: 15,
  categories_created: 15,
  categories_errors: 0,
  products_processed: 1255,
  products_created: 1250,
  products_errors: 5,
  variants_created: 3750,
  variants_errors: 12,
  start_time: 2024-01-15 10:30:00,
  duration: 4500.23
}
```

## Обработка ошибок и edge cases

### Частые проблемы

1. **Дубликаты slug**: Автоматическая генерация уникальных slug
2. **Отсутствие категорий**: Пропуск продуктов без категорий
3. **Некорректные цены**: Установка цены 0 по умолчанию
4. **Rate limiting**: Задержки между запросами
5. **Кириллические slug**: Транслитерация или замена

### Валидация данных

```ruby
# Проверки перед экспортом
def validate_product(product)
  errors = []
  
  errors << "No name" if product.header.blank?
  errors << "No categories" if product.categories.empty?
  errors << "No variants" if product.product_complects.empty?
  
  return errors.empty?, errors
end
```

## Кастомизация

### Добавление новых полей

```ruby
# В файле saleor_research.rb
def self.map_product(rozario_product, category_id, product_type_id)
  {
    # ... существующие поля
    customField: rozario_product.custom_attribute,
    metadata: [
      # ... существующие метаданные
      { key: "custom_field", value: rozario_product.custom_value }
    ]
  }
end
```

### Изменение логики маппинга

```ruby
# Кастомная логика определения типа продукта
def determine_product_type(rozario_product)
  category = rozario_product.categories.first
  
  case category&.title
  when /букет/i
    @product_type_mapping["Букеты"]
  when /композиц/i
    @product_type_mapping["Композиции"]
  else
    @product_type_mapping["Цветы"]
  end
end
```

## Troubleshooting

### Проблема: Connection timeout
```bash
# Увеличить задержки
rake saleor:export DELAY=3 BATCH_SIZE=5
```

### Проблема: Authentication failed
```bash
# Проверить токен
rake saleor:test_connection SALEOR_TOKEN="new_token"
```

### Проблема: Duplicate slug
```ruby
# В логах найти проблемный продукт и исправить вручную
# или добавить автоматическую генерацию уникальных slug
```

### Проблема: Memory issues
```bash
# Уменьшить размер батча
rake saleor:export BATCH_SIZE=1 LIMIT=100
```

## Мониторинг прогресса

### Real-time мониторинг
```bash
# В отдельном терминале
tail -f export.log | grep "Progress:"

# Или использовать watch для статистики
watch -n 10 "grep 'Created product:' export.log | wc -l"
```

### Анализ результатов
```bash
# Подсчет успешных операций
grep "Created product:" export.log | wc -l
grep "Created category:" export.log | wc -l
grep "Created variant:" export.log | wc -l

# Поиск ошибок
grep "ERROR" export.log
grep "Failed to" export.log
```

## Заключение

Данное решение предоставляет полноценную систему экспорта продуктов из Rozario в Saleor с поддержкой:

- ✅ Всех основных сущностей (продукты, категории, варианты)
- ✅ Гибкой конфигурации и фильтрации
- ✅ Надежной обработки ошибок
- ✅ Подробного логирования и статистики
- ✅ Удобных интерфейсов (CLI, Rake, API)
- ✅ Масштабируемости для больших каталогов

Для начала работы рекомендуется:
1. Проверить статистику базы: `rake saleor:stats`
2. Протестировать подключение: `rake saleor:test_connection`
3. Выполнить тестовый экспорт: `rake saleor:export_sample`
4. После проверки результатов запустить полный экспорт

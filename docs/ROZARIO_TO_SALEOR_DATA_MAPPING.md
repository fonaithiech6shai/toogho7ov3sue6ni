# Схема маппинга данных Rozario → Saleor

Детальная схема преобразования данных из базы данных Rozario в структуру Saleor через GraphQL API.

## 📋 Общая архитектура

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ROZARIO DB    │───▶│  RUBY EXPORTER   │───▶│   SALEOR API    │
│   (MySQL)       │    │                  │    │   (GraphQL)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🗂️ Маппинг категорий (Categories)

### Rozario → Saleor Category

```
Rozario.categories                    Saleor.Category
┌─────────────────────┐              ┌──────────────────────┐
│ id (INTEGER)        │─────────────▶│ metadata.rozario_id  │
│ title (VARCHAR)     │─────────────▶│ name (String!)       │
│ slug (VARCHAR)      │─────────────▶│ slug (String!)       │
│ description (TEXT)  │─────────────▶│ description (JSON)    │
│ image (VARCHAR)     │─────────────▶│ [TODO: media upload] │
│ parent_id (INTEGER) │─────────────▶│ parent (Category)     │
│                     │              │                       │
│ seo.title          │─────────────▶│ metadata.seo_title    │
│ seo.description    │─────────────▶│ metadata.seo_desc     │
│ seo.keywords       │─────────────▶│ metadata.seo_keywords │
└─────────────────────┘              └──────────────────────┘
```

**Трансформации:**
- `description (TEXT)` → `description (JSON)` в формате Editor.js
- `image` → требует загрузку файла через Saleor Media API
- SEO данные сохраняются в metadata для возможного восстановления

## 📦 Маппинг продуктов (Products)

### Rozario → Saleor Product

```
Rozario.products                     Saleor.Product
┌─────────────────────┐              ┌──────────────────────┐
│ id (INTEGER)        │─────────────▶│ metadata.rozario_id  │
│ header (VARCHAR)    │─────────────▶│ name (String!)       │
│ title (VARCHAR)     │─────────────▶│ metadata.title       │
│ slug (VARCHAR)      │─────────────▶│ slug (String!)       │
│ description (TEXT)  │─────────────▶│ description (JSON)    │
│ image (VARCHAR)     │─────────────▶│ [TODO: media upload] │
│ discount (INTEGER)  │─────────────▶│ [вычисляется в цене] │
│ default_price (INT) │─────────────▶│ [определяет главн.вар]│
│ trick_price (BOOL)  │─────────────▶│ metadata.trick_price │
│                     │              │                       │
│ seo.title          │─────────────▶│ seoTitle             │
│ seo.description    │─────────────▶│ seoDescription       │
│ seo.keywords       │─────────────▶│ metadata.seo_keywords │
│                     │              │                       │
│ categories (M2M)   │─────────────▶│ category (FK)        │
│ product_complects  │─────────────▶│ variants[]           │
└─────────────────────┘              └──────────────────────┘
```

**Особенности:**
- Rozario поддерживает множественные категории, Saleor - одну основную
- `header` используется как основное название в Saleor
- `title` сохраняется в metadata для полноты данных

## 🔸 Маппинг вариантов продуктов (Product Variants)

### Rozario → Saleor ProductVariant

```
Rozario.product_complects            Saleor.ProductVariant
┌─────────────────────┐              ┌──────────────────────┐
│ id (INTEGER)        │─────────────▶│ metadata.rozario_id  │
│ product_id (FK)     │─────────────▶│ product (FK)         │
│ complect_id (FK)    │─────────────▶│ name + attributes    │
│                     │              │                       │
│ price (INTEGER)     │─────────────▶│ pricing.price        │
│ price_1990 (INT)    │─────────────▶│ metadata.price_1990  │
│ price_2890 (INT)    │─────────────▶│ metadata.price_2890  │
│ price_3790 (INT)    │─────────────▶│ metadata.price_3790  │
│                     │              │                       │
│ over_1290 (INT)     │─────────────▶│ metadata.over_1290   │
│ over_1990 (INT)     │─────────────▶│ metadata.over_1990   │
│ over_2890 (INT)     │─────────────▶│ metadata.over_2890   │
│ over_3790 (INT)     │─────────────▶│ metadata.over_3790   │
│                     │              │                       │
│ image (VARCHAR)     │─────────────▶│ [TODO: media upload] │
│ discounts (JSON)    │─────────────▶│ metadata.discounts   │
│                     │              │                       │
│ complects.title     │─────────────▶│ name (генерируется)  │
│ complects.header    │─────────────▶│ attributes[]         │
└─────────────────────┘              └──────────────────────┘
```

**Сложная логика ценообразования Rozario:**
```
Ценовые пулы:
├── 1290 (базовый)     → price
├── 1990 (региональный) → price_1990 
├── 2890 (премиум)      → price_2890
└── 3790 (VIP)          → price_3790

Надбавки:
├── over_1290 → специальная цена для пула 1290
├── over_1990 → специальная цена для пула 1990  
├── over_2890 → специальная цена для пула 2890
└── over_3790 → специальная цена для пула 3790
```

## 🏷️ Маппинг типов вариантов (Complects)

### Rozario → Saleor Attributes

```
Rozario.complects                    Saleor.Attribute
┌─────────────────────┐              ┌──────────────────────┐
│ id (INTEGER)        │─────────────▶│ metadata.rozario_id  │
│ title (VARCHAR)     │─────────────▶│ name                 │
│ header (VARCHAR)    │─────────────▶│ values[].name        │
└─────────────────────┘              └──────────────────────┘
```

**Стандартные типы Rozario:**
- `standard` → "Стандарт" (основной размер)
- `small` → "Мини" (уменьшенный)
- `lux` → "Люкс" (премиум размер)

## 📊 Маппинг SEO данных

### Rozario → Saleor SEO

```
Rozario.seo                          Saleor.SEO
┌─────────────────────┐              ┌──────────────────────┐
│ title (VARCHAR)     │─────────────▶│ seoTitle             │
│ description (TEXT)  │─────────────▶│ seoDescription       │
│ keywords (VARCHAR)  │─────────────▶│ metadata.keywords    │
└─────────────────────┘              └──────────────────────┘
```

## 🔄 Процесс преобразования данных

### 1. Подготовка описаний (TEXT → JSON)

```ruby
# Rozario
description = "Красивый букет роз"

# ↓ ПРЕОБРАЗОВАНИЕ ↓

# Saleor (Editor.js format)
description = {
  "time": 1699123456789,
  "blocks": [{
    "id": "uuid-here",
    "type": "paragraph", 
    "data": {
      "text": "Красивый букет роз"
    }
  }],
  "version": "2.28.0"
}.to_json
```

### 2. Обработка цен (копейки → рубли)

```ruby
# Rozario (копейки)
price = 2500  # 25.00 рублей

# ↓ ПРЕОБРАЗОВАНИЕ ↓

# Saleor (рубли с точностью)
price = 25.00
costPrice = 17.50  # 70% от цены
```

### 3. Генерация SKU

```ruby
# Rozario
product.slug = "red-roses"
complect.title = "standard"

# ↓ ГЕНЕРАЦИЯ ↓

# Saleor
sku = "red-roses-standard-#{timestamp}"
```

## 📈 Схема связей

```
Rozario Relations                    Saleor Relations
┌─────────────────────┐              ┌──────────────────────┐
│                     │              │                       │
│  Category           │              │  Category             │
│  ├── Products (M2M) │─────────────▶│  ├── Products (1-M)  │
│                     │              │                       │
│  Product            │              │  Product              │
│  ├── Categories(M2M)│─────────────▶│  ├── Category (FK)   │
│  ├── Complects (M2M)│─────────────▶│  ├── Variants (1-M)  │
│  ├── SEO (1-1)      │─────────────▶│  ├── SEO fields      │
│                     │              │                       │
│  ProductComplect    │              │  ProductVariant       │
│  ├── Product (FK)   │─────────────▶│  ├── Product (FK)    │
│  ├── Complect (FK)  │─────────────▶│  ├── Attributes[]    │
│                     │              │                       │
│  Complect           │              │  Attribute            │
│  ├── Products (M2M) │─────────────▶│  ├── Values[]        │
└─────────────────────┘              └──────────────────────┘
```

## 🎯 Метаданные для обратной совместимости

Все оригинальные данные Rozario сохраняются в metadata полях Saleor:

```json
{
  "rozario_id": "123",
  "rozario_title": "Оригинальный title",
  "rozario_seo_title": "SEO заголовок", 
  "rozario_seo_description": "SEO описание",
  "rozario_seo_keywords": "ключевые, слова",
  "rozario_price_1990": "30.00",
  "rozario_price_2890": "45.00",
  "rozario_price_3790": "65.00",
  "rozario_discounts": "[{...}]",
  "rozario_trick_price": "true"
}
```

## ⚡ Использование экспортера

### Команда запуска

```bash
# С моковыми данными (тестирование)
SALEOR_ENDPOINT="https://rozario.eu.saleor.cloud/graphql/" \
SALEOR_TOKEN="ваш-токен" \
ruby rozario_saleor_export_final.rb

# С реальной БД (будущая реализация)
MYSQL_PASSWORD="пароль" \
SALEOR_ENDPOINT="https://rozario.eu.saleor.cloud/graphql/" \
SALEOR_TOKEN="ваш-токен" \
ruby -I lib lib/saleor_export/export_cli.rb
```

### Результат экспорта

```
✅ Экспортировано категорий: 3
✅ Экспортировано продуктов: 3  
✅ Использован тип продукта: Flowers
✅ Сохранены метаданные для восстановления
```

## 🚀 Статус реализации

- ✅ **Базовый экспорт**: Категории + Продукты
- ✅ **Сохранение метаданных**: Полная обратная совместимость
- ✅ **Обработка описаний**: TEXT → JSON (Editor.js)
- ✅ **Тестирование с API**: Реальное подключение к Saleor
- ⏳ **Варианты продуктов**: Требует настройки атрибутов
- ⏳ **Загрузка изображений**: Saleor Media API
- ⏳ **Региональные цены**: Интеграция с Saleor каналами
- ⏳ **Подключение к БД**: MySQL соединение

---

*Обновлено: 10 ноября 2025*
*Версия экспортера: 1.0*

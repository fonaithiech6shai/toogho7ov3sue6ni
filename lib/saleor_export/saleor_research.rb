#!/usr/bin/env ruby
# encoding: utf-8

# Saleor GraphQL API Research
# 
# Этот файл содержит информацию о структуре данных Saleor для экспорта продуктов
# Основано на официальной документации Saleor GraphQL API

class SaleorProductStructure
  # Базовая структура продукта в Saleor
  # 
  # Product:
  # - id
  # - name (обязательное)
  # - slug (обязательное, уникальное)
  # - description (JSON или plain text)
  # - seoTitle
  # - seoDescription  
  # - category (связь с Category)
  # - productType (связь с ProductType)
  # - weight
  # - collections (many-to-many)
  # - attributes (custom attributes)
  # - variants (ProductVariant[])
  # - media (ProductMedia[])
  # - metadata
  #
  # ProductVariant:
  # - id
  # - name
  # - sku (артикул)
  # - price (Money)
  # - costPrice (Money) 
  # - trackInventory
  # - quantityAvailable
  # - weight
  # - media (ProductMedia[])
  # - attributes
  #
  # ProductType:
  # - name
  # - slug
  # - hasVariants (boolean)
  # - isShippingRequired (boolean)
  # - productAttributes
  # - variantAttributes
  #
  # Category:
  # - name
  # - slug  
  # - description
  # - parent (для иерархии)
  # - seoTitle
  # - seoDescription
  # - backgroundImage
  #
  # Collection:
  # - name
  # - slug
  # - description
  # - seoTitle
  # - seoDescription
  # - backgroundImage
  
  SALEOR_MUTATIONS = {
    # Создание категории
    category_create: %[
      mutation CategoryCreate($input: CategoryInput!) {
        categoryCreate(input: $input) {
          errors {
            field
            message
            code
          }
          category {
            id
            name
            slug
          }
        }
      }
    ],
    
    # Создание типа продукта
    product_type_create: %[
      mutation ProductTypeCreate($input: ProductTypeInput!) {
        productTypeCreate(input: $input) {
          errors {
            field
            message
            code
          }
          productType {
            id
            name
            slug
          }
        }
      }
    ],
    
    # Создание продукта
    product_create: %[
      mutation ProductCreate($input: ProductInput!) {
        productCreate(input: $input) {
          errors {
            field
            message
            code
          }
          product {
            id
            name
            slug
            category {
              name
            }
            productType {
              name
            }
          }
        }
      }
    ],
    
    # Создание варианта продукта
    product_variant_create: %[
      mutation ProductVariantCreate($input: ProductVariantInput!) {
        productVariantCreate(input: $input) {
          errors {
            field
            message
            code
          }
          productVariant {
            id
            name
            sku
            price {
              amount
              currency
            }
          }
        }
      }
    ],
    
    # Массовое создание продуктов
    product_bulk_create: %[
      mutation ProductBulkCreate($products: [ProductInput!]!) {
        productBulkCreate(products: $products) {
          count
          results {
            product {
              id
              name
              slug
            }
            errors {
              path
              message
              code
            }
          }
        }
      }
    ]
  }
  
  # Получение информации о существующих категориях
  SALEOR_QUERIES = {
    categories: %[
      query Categories {
        categories(first: 100) {
          edges {
            node {
              id
              name
              slug
              parent {
                id
                name
              }
            }
          }
        }
      }
    ],
    
    product_types: %[
      query ProductTypes {
        productTypes(first: 100) {
          edges {
            node {
              id
              name
              slug
              hasVariants
            }
          }
        }
      }
    ]
  }
end

# Пример маппинга данных Rozario -> Saleor
class RozarioToSaleorMapper
  
  # Мапинг категорий
  def self.map_category(rozario_category)
    {
      name: rozario_category.title,
      slug: rozario_category.slug || slugify(rozario_category.title),
      description: rozario_category.announce,
      seoTitle: rozario_category.seo_title,
      seoDescription: rozario_category.seo_description,
      parent: rozario_category.parent_id ? find_saleor_category_id(rozario_category.parent_id) : nil,
      backgroundImage: rozario_category.image.present? ? image_url(rozario_category.image) : nil
    }
  end
  
  # Мапинг продукта
  def self.map_product(rozario_product, category_id, product_type_id)
    {
      name: rozario_product.header || rozario_product.title,
      slug: slugify(rozario_product.header || rozario_product.title),
      description: format_description(rozario_product),
      seoTitle: rozario_product.description,
      seoDescription: rozario_product.keywords, 
      category: category_id,
      productType: product_type_id,
      weight: 0.5, # Дефолтный вес для цветов
      visible: true,
      availableForPurchase: Time.current.iso8601,
      metadata: [
        { key: "rozario_id", value: rozario_product.id.to_s },
        { key: "rozario_rating", value: rozario_product.rating.to_s },
        { key: "rozario_color", value: rozario_product.color || "" }
      ]
    }
  end
  
  # Мапинг вариантов продукта (комплектаций)
  def self.map_product_variants(rozario_product)
    variants = []
    
    rozario_product.product_complects.each do |complect|
      complect_type = Complect.find(complect.complect_id)
      
      variant = {
        name: "#{rozario_product.header} - #{complect_type.header}",
        sku: "#{rozario_product.id}-#{complect.complect_id}",
        trackInventory: false,
        price: complect.price || 0,
        costPrice: (complect.price || 0) * 0.6, # Примерная себестоимость
        weight: get_variant_weight(complect_type.title),
        metadata: [
          { key: "rozario_complect_id", value: complect.id.to_s },
          { key: "rozario_complect_type", value: complect_type.title },
          { key: "original_price", value: complect.price.to_s }
        ]
      }
      
      # Добавляем медиа если есть изображение
      if complect.image.present?
        variant[:media] = [{
          image: image_url(complect.image),
          alt: "#{rozario_product.header} - #{complect_type.header}"
        }]
      end
      
      variants << variant
    end
    
    variants
  end
  
  private
  
  def self.slugify(text)
    return "" if text.blank?
    # Простая русификация slug
    text.strip.downcase
        .gsub(/[а-я]+/, '') # Удаляем кириллицу для совместимости
        .gsub(/[^a-z0-9\s-]/, '') # Оставляем только разрешенные символы
        .gsub(/\s+/, '-') # Заменяем пробелы на дефисы
        .gsub(/-+/, '-') # Убираем множественные дефисы
        .gsub(/^-+|-+$/, '') # Убираем дефисы в начале и конце
  end
  
  def self.format_description(product)
    description = []
    description << product.announce if product.announce.present?
    description << product.text if product.text.present?
    
    # Форматируем в JSON для rich text
    {
      "blocks" => [
        {
          "type" => "paragraph",
          "data" => {
            "text" => description.join("\n\n")
          }
        }
      ]
    }.to_json
  end
  
  def self.image_url(image_path)
    # Формируем полный URL изображения
    return nil if image_path.blank?
    "https://rozarioflowers.ru/uploads/#{image_path}"
  end
  
  def self.get_variant_weight(complect_type)
    weights = {
      'small' => 0.3,
      'standard' => 0.5, 
      'lux' => 0.8
    }
    weights[complect_type] || 0.5
  end
  
  def self.find_saleor_category_id(rozario_category_id)
    # В реальной реализации здесь будет поиск по маппингу
    # rozario_id -> saleor_id
    nil
  end
end

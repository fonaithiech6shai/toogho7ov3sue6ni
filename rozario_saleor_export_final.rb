#!/usr/bin/env ruby
# encoding: utf-8

# Финальная рабочая версия экспорта Rozario → Saleor
require 'net/http'
require 'json'
require 'uri'
require 'securerandom'

class RozarioSaleorExporter
  def initialize(endpoint, token)
    @endpoint = endpoint
    @token = token
  end

  def test_connection
    puts "🔗 Проверяем подключение к Saleor..."
    
    query = {
      query: "query { shop { name description } }"
    }
    
    response = make_request(query)
    
    if response && response['data'] && response['data']['shop']
      shop = response['data']['shop']
      puts "   ✅ Подключение успешно!"
      puts "   📋 Магазин: #{shop['name']}"
      return true
    else
      puts "   ❌ Ошибка подключения"
      return false
    end
  end

  def create_category(name, slug, description = "")
    puts "📁 Создаем категорию: #{name}"
    
    # Создаем описание в формате JSON для Saleor
    json_description = {
      time: Time.now.to_i * 1000,
      blocks: [{
        id: SecureRandom.uuid,
        type: "paragraph",
        data: { text: description }
      }],
      version: "2.28.0"
    }.to_json
    
    mutation = {
      query: """
        mutation CreateCategory($input: CategoryInput!) {
          categoryCreate(input: $input) {
            category {
              id
              name
              slug
            }
            errors {
              field
              message
              code
            }
          }
        }
      """,
      variables: {
        input: {
          name: name,
          slug: slug,
          description: json_description
        }
      }
    }
    
    response = make_request(mutation)
    
    if response && response['data'] && response['data']['categoryCreate']
      result = response['data']['categoryCreate']
      if result['errors'] && result['errors'].any?
        puts "   ❌ Ошибка: #{result['errors'].map { |e| e['message'] }.join(', ')}"
        return nil
      elsif result['category']
        puts "   ✅ Категория создана: #{result['category']['id']}"
        return result['category']
      end
    end
    
    puts "   ❌ Не удалось создать категорию"
    puts "   📋 Ответ сервера: #{response}" if response
    return nil
  end

  def get_default_product_type
    query = {
      query: """
        query {
          productTypes(first: 10) {
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
      """
    }
    
    response = make_request(query)
    
    if response && response['data'] && response['data']['productTypes']
      product_types = response['data']['productTypes']['edges']
      if product_types.any?
        # Ищем тип с вариантами, если есть
        variant_type = product_types.find { |pt| pt['node']['hasVariants'] }
        default_type = variant_type ? variant_type['node'] : product_types.first['node']
        puts "   🏷️  Используем тип: #{default_type['name']} (варианты: #{default_type['hasVariants']})"
        return default_type
      end
    end
    
    puts "   ❌ Не найдено типов продуктов"
    return nil
  end

  def create_product(name, slug, description, category_id, product_type_id, variants = [])
    puts "📦 Создаем продукт: #{name}"
    
    # Создаем описание в формате JSON
    json_description = {
      time: Time.now.to_i * 1000,
      blocks: [{
        id: SecureRandom.uuid,
        type: "paragraph",
        data: { text: description }
      }],
      version: "2.28.0"
    }.to_json
    
    mutation = {
      query: """
        mutation CreateProduct($input: ProductCreateInput!) {
          productCreate(input: $input) {
            product {
              id
              name
              slug
            }
            errors {
              field
              message
              code
            }
          }
        }
      """,
      variables: {
        input: {
          name: name,
          slug: slug,
          description: json_description,
          category: category_id,
          productType: product_type_id
        }
      }
    }
    
    response = make_request(mutation)
    
    if response && response['data'] && response['data']['productCreate']
      result = response['data']['productCreate']
      if result['errors'] && result['errors'].any?
        puts "   ❌ Ошибка создания продукта: #{result['errors'].map { |e| e['message'] }.join(', ')}"
        return nil
      elsif result['product']
        product = result['product']
        puts "   ✅ Продукт создан: #{product['id']}"
        
        # Создаем варианты продукта
        if variants.any?
          variants.each_with_index do |variant_data, index|
            create_product_variant(product['id'], variant_data, index == 0)
          end
        end
        
        return product
      end
    end
    
    puts "   ❌ Не удалось создать продукт"
    puts "   📋 Ответ сервера: #{response}" if response
    return nil
  end

  def create_product_variant(product_id, variant_data, is_default = false)
    puts "   🔸 Создаем вариант: #{variant_data[:name]}"
    
    mutation = {
      query: """
        mutation CreateProductVariant($input: ProductVariantCreateInput!) {
          productVariantCreate(input: $input) {
            productVariant {
              id
              name
              sku
            }
            errors {
              field
              message
              code
            }
          }
        }
      """,
      variables: {
        input: {
          product: product_id,
          name: variant_data[:name],
          sku: variant_data[:sku],
          trackInventory: false,
          attributes: []
        }
      }
    }
    
    response = make_request(mutation)
    
    if response && response['data'] && response['data']['productVariantCreate']
      result = response['data']['productVariantCreate']
      if result['errors'] && result['errors'].any?
        puts "     ❌ Ошибка: #{result['errors'].map { |e| e['message'] }.join(', ')}"
        return nil
      elsif result['productVariant']
        variant = result['productVariant']
        puts "     ✅ Вариант создан: #{variant['id']}"
        
        # Устанавливаем цену если указана
        if variant_data[:price]
          set_variant_price(variant['id'], variant_data[:price])
        end
        
        return variant
      end
    end
    
    puts "     ❌ Не удалось создать вариант"
    puts "     📋 Ответ сервера: #{response}" if response
    return nil
  end

  def set_variant_price(variant_id, price)
    puts "     💰 Устанавливаем цену: #{price} RUB"
    
    # Получаем канал по умолчанию
    channel_id = get_default_channel_id
    return false unless channel_id
    
    mutation = {
      query: """
        mutation SetVariantChannelListing($id: ID!, $input: [ProductVariantChannelListingAddInput!]!) {
          productVariantChannelListingUpdate(id: $id, input: $input) {
            variant {
              id
            }
            errors {
              field
              message
              code
            }
          }
        }
      """,
      variables: {
        id: variant_id,
        input: [{
          channelId: channel_id,
          price: price,
          costPrice: (price * 0.7).round(2)
        }]
      }
    }
    
    response = make_request(mutation)
    
    if response && response['data'] && response['data']['productVariantChannelListingUpdate']
      result = response['data']['productVariantChannelListingUpdate']
      if result['errors'] && result['errors'].any?
        puts "       ❌ Ошибка установки цены: #{result['errors'].map { |e| e['message'] }.join(', ')}"
        return false
      else
        puts "       ✅ Цена установлена"
        return true
      end
    end
    
    puts "       ❌ Не удалось установить цену"
    return false
  end

  def get_default_channel_id
    @default_channel_id ||= begin
      query = {
        query: "query { channels { id name isActive } }"
      }
      
      response = make_request(query)
      
      if response && response['data'] && response['data']['channels']
        active_channel = response['data']['channels'].find { |c| c['isActive'] }
        active_channel ? active_channel['id'] : nil
      else
        nil
      end
    end
  end

  private

  def make_request(data)
    uri = URI(@endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = data.to_json
    
    begin
      response = http.request(request)
      JSON.parse(response.body)
    rescue => e
      puts "   ❌ Ошибка запроса: #{e.message}"
      nil
    end
  end
end

# Создание тестовых данных (моковые данные Rozario)
def create_rozario_mock_data
  puts "📋 Создаем тестовые данные Rozario..."
  
  categories = [
    { id: 1, name: "Розы", slug: "rozy-#{Time.now.to_i}", description: "Красивая коллекция роз разных сортов" },
    { id: 2, name: "Букеты", slug: "bukety-#{Time.now.to_i}", description: "Свадебные и праздничные букеты на заказ" },
    { id: 3, name: "Подарки", slug: "podarki-#{Time.now.to_i}", description: "Цветочные подарки и композиции для особых случаев" }
  ]
  
  products = [
    {
      id: 1,
      name: "Букет красных роз",
      slug: "buket-krasnyh-roz-#{Time.now.to_i}-1",
      description: "Элегантный букет из свежих красных роз эквадорского производства. Идеально подходит для выражения чувств.",
      category_id: 1,
      variants: [
        { name: "Стандарт (11 роз)", sku: "rose-red-standard-#{Time.now.to_i}", price: 25.00, type: "standard" },
        { name: "Мини (7 роз)", sku: "rose-red-small-#{Time.now.to_i}", price: 18.00, type: "small" },
        { name: "Люкс (25 роз)", sku: "rose-red-lux-#{Time.now.to_i}", price: 55.00, type: "lux" }
      ]
    },
    {
      id: 2,
      name: "Композиция белых роз",
      slug: "kompoziciya-belyh-roz-#{Time.now.to_i}-2",
      description: "Изысканная композиция из белых роз в стильной упаковке. Символ чистоты и нежности.",
      category_id: 1,
      variants: [
        { name: "Стандарт (15 роз)", sku: "rose-white-standard-#{Time.now.to_i}", price: 28.00, type: "standard" },
        { name: "Мини (9 роз)", sku: "rose-white-small-#{Time.now.to_i}", price: 20.00, type: "small" },
        { name: "Люкс (31 роза)", sku: "rose-white-lux-#{Time.now.to_i}", price: 62.00, type: "lux" }
      ]
    },
    {
      id: 3,
      name: "Смешанный букет \"Радуга\"",
      slug: "smeshannyj-buket-raduga-#{Time.now.to_i}-3",
      description: "Яркий букет из сезонных цветов: розы, хризантемы, герберы. Создает праздничное настроение.",
      category_id: 2,
      variants: [
        { name: "Стандарт", sku: "mixed-standard-#{Time.now.to_i}", price: 22.00, type: "standard" },
        { name: "Мини", sku: "mixed-small-#{Time.now.to_i}", price: 16.00, type: "small" },
        { name: "Люкс", sku: "mixed-lux-#{Time.now.to_i}", price: 38.00, type: "lux" }
      ]
    }
  ]
  
  puts "   ✅ Создано #{categories.length} категорий"
  puts "   ✅ Создано #{products.length} продуктов"
  puts "   ✅ Всего вариантов: #{products.sum { |p| p[:variants].length }}"
  
  { categories: categories, products: products }
end

# Основная функция экспорта
def run_rozario_export
  puts "🌿 Rozario → Saleor: Экспорт с моковыми данными"
  puts "=" * 50
  
  endpoint = ENV['SALEOR_ENDPOINT']
  token = ENV['SALEOR_TOKEN']
  
  unless endpoint && token
    puts "❌ Необходимы переменные окружения: SALEOR_ENDPOINT и SALEOR_TOKEN"
    return false
  end
  
  # Создаем экспортер
  exporter = RozarioSaleorExporter.new(endpoint, token)
  
  # Проверяем подключение
  return false unless exporter.test_connection
  
  # Создаем моковые данные
  mock_data = create_rozario_mock_data
  
  puts "\n📤 Начинаем экспорт..."
  
  # Получаем тип продукта
  product_type = exporter.get_default_product_type
  return false unless product_type
  
  exported_categories = {}
  exported_products = {}
  
  # Экспортируем категории
  puts "\n📁 Экспорт категорий:"
  mock_data[:categories].each do |cat_data|
    category = exporter.create_category(
      cat_data[:name],
      cat_data[:slug],
      cat_data[:description]
    )
    
    if category
      exported_categories[cat_data[:id]] = category['id']
    else
      puts "   ⚠️  Пропускаем продукты категории: #{cat_data[:name]}"
    end
    
    sleep(1) # Пауза между запросами
  end
  
  # Экспортируем продукты
  puts "\n📦 Экспорт продуктов:"
  mock_data[:products].each do |prod_data|
    category_id = exported_categories[prod_data[:category_id]]
    
    if category_id
      product = exporter.create_product(
        prod_data[:name],
        prod_data[:slug],
        prod_data[:description],
        category_id,
        product_type['id'],
        prod_data[:variants]
      )
      
      if product
        exported_products[prod_data[:id]] = product['id']
      end
    else
      puts "   ⚠️  Пропускаем продукт (нет категории): #{prod_data[:name]}"
    end
    
    sleep(2) # Пауза между продуктами
  end
  
  # Результаты
  puts "\n🎉 Экспорт завершен!"
  puts "   ✅ Экспортировано категорий: #{exported_categories.length}"
  puts "   ✅ Экспортировано продуктов: #{exported_products.length}"
  puts "   ✅ Использован тип продукта: #{product_type['name']}"
  
  total_variants = mock_data[:products].select { |p| exported_products[p[:id]] }.sum { |p| p[:variants].length }
  puts "   ✅ Создано вариантов: #{total_variants}"
  
  puts "\n🔗 Проверить результаты:"
  puts "   📊 Админка Saleor: https://rozario.eu.saleor.cloud/dashboard/"
  puts "   📂 Категории: https://rozario.eu.saleor.cloud/dashboard/categories/"
  puts "   📦 Продукты: https://rozario.eu.saleor.cloud/dashboard/products/"
  
  return true
end

# Запуск
if __FILE__ == $0
  if run_rozario_export
    puts "\n✨ Тест успешно завершен!"
    puts "\n📝 Следующие шаги:"
    puts "   1. Проверьте созданные данные в админке Saleor"
    puts "   2. При необходимости запустите полный экспорт с реальными данными из БД"
    puts "   3. Настройте дополнительные поля и атрибуты продуктов"
    puts "   4. Добавьте загрузку изображений"
    puts "   5. Настройте SEO метаданные"
  else
    puts "\n❌ Тест не прошел - проверьте подключение и параметры"
    exit 1
  end
end

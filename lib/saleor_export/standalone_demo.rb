#!/usr/bin/env ruby
# encoding: utf-8

# Standalone демо экспортера (without Padrino dependencies)
# Использование: ruby lib/saleor_export/standalone_demo.rb

require 'net/http'
require 'json'
require 'uri'

# Mock классы для демонстрации
class MockProduct
  attr_accessor :id, :header, :title, :announce, :text, :description, :keywords, :rating, :color
  
  def initialize(data = {})
    @id = data[:id] || 1
    @header = data[:header] || "Букет 'Романс'"
    @title = data[:title] || "Красивые цветы"
    @announce = data[:announce] || "Нежный букет для любимой"
    @text = data[:text] || "Подробное описание товара"
    @description = data[:description] || "SEO description"
    @keywords = data[:keywords] || "SEO keywords" 
    @rating = data[:rating] || 5
    @color = data[:color] || "красный"
  end
end

class MockCategory
  attr_accessor :id, :title, :slug, :announce, :seo_title, :seo_description, :parent_id
  
  def initialize(data = {})
    @id = data[:id] || 1
    @title = data[:title] || "Букеты"
    @slug = data[:slug] || "bouquets"
    @announce = data[:announce] || "Красивые букеты"
    @seo_title = data[:seo_title] || "Букеты цветов - SEO"
    @seo_description = data[:seo_description] || "SEO описание"
    @parent_id = data[:parent_id]
  end
end

class MockComplect
  attr_accessor :id, :title, :header, :price, :image
  
  def initialize(data = {})
    @id = data[:id] || 1
    @title = data[:title] || "standard"
    @header = data[:header] || "Стандарт"
    @price = data[:price] || 2500
    @image = data[:image] || "product_123.jpg"
  end
end

# Упрощенная версия маппера
class SaleorMapper
  def self.map_category(rozario_category)
    {
      name: rozario_category.title,
      slug: slugify(rozario_category.title),
      description: rozario_category.announce,
      seoTitle: rozario_category.seo_title,
      seoDescription: rozario_category.seo_description,
      parent: rozario_category.parent_id ? "parent_#{rozario_category.parent_id}" : nil
    }
  end
  
  def self.map_product(rozario_product, category_id, product_type_id)
    {
      name: rozario_product.header || rozario_product.title,
      slug: slugify(rozario_product.header || rozario_product.title),
      description: format_description(rozario_product),
      seoTitle: rozario_product.description,
      seoDescription: rozario_product.keywords,
      category: category_id,
      productType: product_type_id,
      weight: 0.5,
      visible: true,
      availableForPurchase: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      metadata: [
        { key: "rozario_id", value: rozario_product.id.to_s },
        { key: "rozario_rating", value: rozario_product.rating.to_s },
        { key: "rozario_color", value: rozario_product.color || "" }
      ]
    }
  end
  
  def self.map_variant(rozario_product, complect)
    {
      name: "#{rozario_product.header} - #{complect.header}",
      sku: "#{rozario_product.id}-#{complect.id}",
      price: complect.price,
      costPrice: (complect.price * 0.6).to_i,
      weight: 0.5,
      trackInventory: false,
      metadata: [
        { key: "rozario_complect_id", value: complect.id.to_s },
        { key: "rozario_complect_type", value: complect.title }
      ]
    }
  end
  
  private
  
  def self.slugify(text)
    return "" if text.nil? || text.empty?
    text.strip.downcase
        .gsub(/[а-яА-Я]/, '') # Убираем кириллицу
        .gsub(/[^a-z0-9\s-]/, '')
        .gsub(/\s+/, '-')
        .gsub(/-+/, '-')
        .gsub(/^-+|-+$/, '')
  end
  
  def self.format_description(product)
    description = []
    description << product.announce if product.announce && !product.announce.empty?
    description << product.text if product.text && !product.text.empty?
    
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
end

# Упрощенный экспортер
class SimpleSaleorExporter
  attr_reader :endpoint, :token
  
  def initialize(endpoint, token)
    @endpoint = endpoint
    @token = token
  end
  
  def test_connection
    query = %{
      query {
        categories(first: 1) {
          edges {
            node {
              id
              name
            }
          }
        }
      }
    }
    
    response = graphql_request(query)
    !response['errors']
  rescue => e
    puts "Connection error: #{e.message}"
    false
  end
  
  def create_category(category_data)
    mutation = %{
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
    }
    
    response = graphql_request(mutation, { input: category_data })
    
    if response.dig('data', 'categoryCreate', 'errors')&.empty?
      category = response.dig('data', 'categoryCreate', 'category')
      puts "✓ Category created: #{category['name']} (#{category['id']})"
      category
    else
      errors = response.dig('data', 'categoryCreate', 'errors') || response['errors']
      puts "❌ Failed to create category: #{errors}"
      nil
    end
  end
  
  def create_product_type(type_data)
    mutation = %{
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
    }
    
    response = graphql_request(mutation, { input: type_data })
    
    if response.dig('data', 'productTypeCreate', 'errors')&.empty?
      product_type = response.dig('data', 'productTypeCreate', 'productType')
      puts "✓ Product type created: #{product_type['name']} (#{product_type['id']})"
      product_type
    else
      errors = response.dig('data', 'productTypeCreate', 'errors') || response['errors']
      puts "❌ Failed to create product type: #{errors}"
      nil
    end
  end
  
  def demo_export
    puts "\n🚀 Saleor Export Demo"
    puts "=" * 30
    
    # 1. Тест подключения
    puts "\n1. Testing connection..."
    unless test_connection
      puts "❌ Connection failed!"
      return
    end
    puts "✓ Connection successful!"
    
    # 2. Создание типа продукта
    puts "\n2. Creating product type..."
    product_type = create_product_type({
      name: "Цветы Demo",
      slug: "flowers-demo",
      hasVariants: true,
      isShippingRequired: true
    })
    
    unless product_type
      puts "❌ Failed to create product type!"
      return
    end
    
    # 3. Создание категории
    puts "\n3. Creating category..."
    mock_category = MockCategory.new(title: "Тестовые букеты")
    category_data = SaleorMapper.map_category(mock_category)
    category = create_category(category_data)
    
    unless category
      puts "❌ Failed to create category!"
      return
    end
    
    # 4. Показать маппинг продукта
    puts "\n4. Product mapping demo..."
    mock_product = MockProduct.new({
      id: 123,
      header: "Букет 'Романс Demo'",
      announce: "Нежный букет для любимой",
      rating: 5,
      color: "красный"
    })
    
    product_data = SaleorMapper.map_product(mock_product, category['id'], product_type['id'])
    puts "Product data structure:"
    puts JSON.pretty_generate(product_data)
    
    # 5. Показать маппинг вариантов
    puts "\n5. Variant mapping demo..."
    complects = [
      MockComplect.new(id: 1, title: "standard", header: "Стандарт", price: 2500),
      MockComplect.new(id: 2, title: "lux", header: "Люкс", price: 3500)
    ]
    
    complects.each do |complect|
      variant_data = SaleorMapper.map_variant(mock_product, complect)
      puts "\nVariant: #{complect.header}"
      puts JSON.pretty_generate(variant_data)
    end
    
    puts "\n🎉 Demo completed successfully!"
    puts "\n📝 Next steps:"
    puts "- Set up real Saleor endpoint and token"
    puts "- Run: rake saleor:export_sample"
    puts "- Check results in Saleor admin panel"
  end
  
  private
  
  def graphql_request(query, variables = {})
    uri = URI(@endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@token}" if @token
    
    payload = {
      query: query.strip,
      variables: variables
    }
    
    request.body = payload.to_json
    
    response = http.request(request)
    
    if response.code != '200'
      raise "HTTP #{response.code}: #{response.body}"
    end
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise "Invalid JSON response: #{e.message}"
  end
end

# Interactive demo
def interactive_demo
  puts "\n🌿 Saleor Export - Interactive Demo"
  puts "=" * 40
  
  puts "\n📁 This demo will show you how the export system works:"
  puts "1. Test connection to Saleor API"
  puts "2. Create sample product type"
  puts "3. Create sample category"
  puts "4. Show product data mapping"
  puts "5. Show variant data mapping"
  
  puts "\n🔗 Enter your Saleor API details:"
  print "GraphQL Endpoint: "
  endpoint = gets.chomp
  
  if endpoint.empty?
    puts "\n💡 Using demo mode (no actual API calls)"
    demo_mode
    return
  end
  
  print "Auth Token: "
  token = gets.chomp
  
  if token.empty?
    puts "\n⚠️  Token is required for API calls"
    puts "Using demo mode instead..."
    demo_mode
    return
  end
  
  # Запуск реальной демо
  exporter = SimpleSaleorExporter.new(endpoint, token)
  exporter.demo_export
end

def demo_mode
  puts "\n🎭 Demo Mode - Showing data structures without API calls"
  puts "=" * 55
  
  # Мок данные
  category = MockCategory.new
  product = MockProduct.new
  complect = MockComplect.new
  
  puts "\n1. Category mapping:"
  puts JSON.pretty_generate(SaleorMapper.map_category(category))
  
  puts "\n2. Product mapping:"
  puts JSON.pretty_generate(SaleorMapper.map_product(product, "category123", "producttype456"))
  
  puts "\n3. Variant mapping:"
  puts JSON.pretty_generate(SaleorMapper.map_variant(product, complect))
  
  puts "\n📈 Sample statistics:"
  puts "- Would export: 1 category, 1 product, 1 variant"
  puts "- Estimated time: ~5 seconds"
  
  puts "\n📝 To run with real data:"
  puts "1. Set up Saleor instance"
  puts "2. Get API token with proper permissions"
  puts "3. Run: rake saleor:export_sample SALEOR_ENDPOINT=... SALEOR_TOKEN=..."
end

# Запуск демо если вызван напрямую
if __FILE__ == $0
  interactive_demo
end

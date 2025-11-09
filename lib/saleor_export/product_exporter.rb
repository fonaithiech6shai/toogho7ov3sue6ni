#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'json'
require 'uri'
require 'logger'

require_relative 'saleor_research'

class SaleorProductExporter
  include RozarioToSaleorMapper
  
  attr_reader :saleor_endpoint, :auth_token, :logger, :stats
  
  def initialize(saleor_endpoint, auth_token, options = {})
    @saleor_endpoint = saleor_endpoint
    @auth_token = auth_token
    @logger = options[:logger] || Logger.new(STDOUT)
    @batch_size = options[:batch_size] || 10
    @delay_between_requests = options[:delay] || 1
    
    @stats = {
      categories_processed: 0,
      categories_created: 0,
      categories_errors: 0,
      products_processed: 0,
      products_created: 0,
      products_errors: 0,
      variants_created: 0,
      variants_errors: 0,
      start_time: Time.current
    }
    
    @category_mapping = {} # rozario_id => saleor_id
    @product_type_mapping = {} # name => saleor_id
    
    logger.info "SaleorProductExporter initialized: #{saleor_endpoint}"
  end
  
  # Основной метод экспорта
  def export_all(options = {})
    logger.info "Starting full export..."
    
    begin
      # 1. Проверяем подключение
      unless test_connection
        raise "Failed to connect to Saleor API"
      end
      
      # 2. Экспорт категорий
      export_categories if options[:export_categories] != false
      
      # 3. Создаем базовые типы продуктов
      create_product_types if options[:create_product_types] != false
      
      # 4. Экспорт продуктов
      export_products(options)
      
      log_final_stats
      logger.info "Export completed successfully!"
      
      return {
        success: true,
        stats: @stats,
        duration: Time.current - @stats[:start_time]
      }
      
    rescue => e
      logger.error "Export failed: #{e.message}"
      logger.error e.backtrace.join("\n")
      
      return {
        success: false,
        error: e.message,
        stats: @stats
      }
    end
  end
  
  # Экспорт только категорий
  def export_categories
    logger.info "Exporting categories..."
    
    # Сначала экспортируем родительские категории
    root_categories = Category.where(parent_id: [0, nil])
    root_categories.each { |category| export_category(category) }
    
    # Затем дочерние
    child_categories = Category.where.not(parent_id: [0, nil])
    child_categories.each { |category| export_category(category) }
    
    logger.info "Categories export completed. Created: #{@stats[:categories_created]}, Errors: #{@stats[:categories_errors]}"
  end
  
  # Экспорт одной категории
  def export_category(rozario_category)
    @stats[:categories_processed] += 1
    
    begin
      category_data = RozarioToSaleorMapper.map_category(rozario_category)
      
      # Посылаем запрос на создание
      response = graphql_request(SaleorProductStructure::SALEOR_MUTATIONS[:category_create], {
        input: category_data
      })
      
      if response['errors']&.any?
        logger.error "Failed to create category '#{rozario_category.title}': #{response['errors']}"
        @stats[:categories_errors] += 1
        return false
      end
      
      saleor_category = response.dig('data', 'categoryCreate', 'category')
      if saleor_category
        @category_mapping[rozario_category.id] = saleor_category['id']
        @stats[:categories_created] += 1
        logger.info "Created category: #{saleor_category['name']} (#{saleor_category['id']})"
        return true
      else
        logger.error "Failed to create category '#{rozario_category.title}': no category returned"
        @stats[:categories_errors] += 1
        return false
      end
      
    rescue => e
      logger.error "Error exporting category #{rozario_category.id}: #{e.message}"
      @stats[:categories_errors] += 1
      return false
    ensure
      sleep(@delay_between_requests)
    end
  end
  
  # Создание базовых типов продуктов
  def create_product_types
    logger.info "Creating product types..."
    
    product_types = [
      {
        name: "Цветы",
        slug: "flowers",
        hasVariants: true,
        isShippingRequired: true,
        weight: 'GRAM'
      },
      {
        name: "Композиции",
        slug: "compositions", 
        hasVariants: true,
        isShippingRequired: true,
        weight: 'GRAM'
      },
      {
        name: "Букеты",
        slug: "bouquets",
        hasVariants: true, 
        isShippingRequired: true,
        weight: 'GRAM'
      }
    ]
    
    product_types.each do |pt_data|
      response = graphql_request(SaleorProductStructure::SALEOR_MUTATIONS[:product_type_create], {
        input: pt_data
      })
      
      if response['errors']&.empty?
        product_type = response.dig('data', 'productTypeCreate', 'productType')
        @product_type_mapping[pt_data[:name]] = product_type['id']
        logger.info "Created product type: #{pt_data[:name]}"
      else
        logger.warn "Failed to create product type #{pt_data[:name]}: #{response['errors']}"
      end
      
      sleep(@delay_between_requests)
    end
  end
  
  # Экспорт продуктов
  def export_products(options = {})
    logger.info "Exporting products..."
    
    # Фильтры
    query = Product.joins(:product_complects).includes(:categories, :product_complects, :complects)
    query = query.where(id: options[:product_ids]) if options[:product_ids]
    query = query.limit(options[:limit]) if options[:limit]
    
    total_products = query.count
    logger.info "Found #{total_products} products to export"
    
    query.find_in_batches(batch_size: @batch_size) do |batch|
      batch.each do |product|
        export_product(product)
        sleep(@delay_between_requests)
      end
      
      progress = ((@stats[:products_processed].to_f / total_products) * 100).round(1)
      logger.info "Progress: #{@stats[:products_processed]}/#{total_products} (#{progress}%)"
    end
    
    logger.info "Products export completed. Created: #{@stats[:products_created]}, Errors: #{@stats[:products_errors]}"
  end
  
  # Экспорт одного продукта
  def export_product(rozario_product)
    @stats[:products_processed] += 1
    
    begin
      # Определяем категорию и тип продукта
      category = rozario_product.categories.first
      category_id = category ? @category_mapping[category.id] : nil
      product_type_id = @product_type_mapping["Цветы"] # Дефолт
      
      if category_id.nil?
        logger.warn "Skipping product #{rozario_product.id}: no mapped category"
        return false
      end
      
      # Мапим основные данные
      product_data = RozarioToSaleorMapper.map_product(rozario_product, category_id, product_type_id)
      
      # Создаем продукт
      response = graphql_request(SaleorProductStructure::SALEOR_MUTATIONS[:product_create], {
        input: product_data
      })
      
      if response['errors']&.any?
        logger.error "Failed to create product '#{rozario_product.header}': #{response['errors']}"
        @stats[:products_errors] += 1
        return false
      end
      
      saleor_product = response.dig('data', 'productCreate', 'product')
      unless saleor_product
        logger.error "Failed to create product '#{rozario_product.header}': no product returned"
        @stats[:products_errors] += 1
        return false
      end
      
      @stats[:products_created] += 1
      logger.info "Created product: #{saleor_product['name']} (#{saleor_product['id']})"
      
      # Создаем варианты (комплектации)
      export_product_variants(rozario_product, saleor_product['id'])
      
      return true
      
    rescue => e
      logger.error "Error exporting product #{rozario_product.id}: #{e.message}"
      @stats[:products_errors] += 1
      return false
    end
  end
  
  # Экспорт вариантов продукта
  def export_product_variants(rozario_product, saleor_product_id)
    variants_data = RozarioToSaleorMapper.map_product_variants(rozario_product)
    
    variants_data.each do |variant_data|
      variant_data[:product] = saleor_product_id
      
      response = graphql_request(SaleorProductStructure::SALEOR_MUTATIONS[:product_variant_create], {
        input: variant_data
      })
      
      if response['errors']&.empty?
        @stats[:variants_created] += 1
        variant = response.dig('data', 'productVariantCreate', 'productVariant')
        logger.debug "Created variant: #{variant['name']} (#{variant['sku']})"
      else
        @stats[:variants_errors] += 1
        logger.error "Failed to create variant: #{response['errors']}"
      end
      
      sleep(@delay_between_requests / 2) # Меньшая задержка для вариантов
    end
  end
  
  # Проверка подключения к API
  def test_connection
    begin
      response = graphql_request(SaleorProductStructure::SALEOR_QUERIES[:categories])
      return response && !response['errors']
    rescue => e
      logger.error "Connection test failed: #{e.message}"
      return false
    end
  end
  
  # Вывод финальной статистики
  def log_final_stats
    duration = Time.current - @stats[:start_time]
    
    logger.info "=== EXPORT STATISTICS ==="
    logger.info "Duration: #{duration.round(2)} seconds"
    logger.info "Categories: #{@stats[:categories_created]} created, #{@stats[:categories_errors]} errors"
    logger.info "Products: #{@stats[:products_created]} created, #{@stats[:products_errors]} errors"
    logger.info "Variants: #{@stats[:variants_created]} created, #{@stats[:variants_errors]} errors"
    logger.info "Total processed: #{@stats[:products_processed]} products, #{@stats[:categories_processed]} categories"
    logger.info "========================"
  end
  
  private
  
  # Отправка GraphQL запроса
  def graphql_request(query, variables = {})
    uri = URI(@saleor_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@auth_token}" if @auth_token
    
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

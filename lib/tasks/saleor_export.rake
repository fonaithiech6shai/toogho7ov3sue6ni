# encoding: utf-8
# Rake задачи для экспорта данных в Saleor
# 
# Использование:
#   rake saleor:export SALEOR_ENDPOINT=https://your-store.saleor.cloud/graphql/ SALEOR_TOKEN=your_token
#   rake saleor:test_connection SALEOR_ENDPOINT=https://your-store.saleor.cloud/graphql/ SALEOR_TOKEN=your_token
#   rake saleor:export_sample SALEOR_ENDPOINT=... SALEOR_TOKEN=... LIMIT=10

require_relative '../saleor_export/product_exporter'

namespace :saleor do
  desc "Экспорт всех продуктов и категорий в Saleor"
  task :export => :environment do
    endpoint = ENV['SALEOR_ENDPOINT']
    token = ENV['SALEOR_TOKEN']
    
    unless endpoint && token
      puts "Error: Please set SALEOR_ENDPOINT and SALEOR_TOKEN environment variables"
      puts "Example: rake saleor:export SALEOR_ENDPOINT=https://mystore.saleor.cloud/graphql/ SALEOR_TOKEN=abc123"
      exit 1
    end
    
    logger = Logger.new(STDOUT)
    logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    
    exporter = SaleorProductExporter.new(endpoint, token, {
      logger: logger,
      batch_size: ENV['BATCH_SIZE']&.to_i || 10,
      delay: ENV['DELAY']&.to_f || 1
    })
    
    options = {}
    options[:limit] = ENV['LIMIT'].to_i if ENV['LIMIT']
    options[:product_ids] = ENV['PRODUCT_IDS'].split(',').map(&:to_i) if ENV['PRODUCT_IDS']
    options[:export_categories] = ENV['SKIP_CATEGORIES'] != 'true'
    options[:create_product_types] = ENV['SKIP_PRODUCT_TYPES'] != 'true'
    
    puts "\n🚀 Starting Saleor export..."
    puts "Endpoint: #{endpoint}"
    puts "Options: #{options.inspect}\n\n"
    
    result = exporter.export_all(options)
    
    if result[:success]
      puts "\n🎉 Export completed successfully!"
      puts "Duration: #{result[:duration].round(2)} seconds"
      
      # Сохраняем статистику
      if ENV['STATS_FILE']
        File.open(ENV['STATS_FILE'], 'w') do |f|
          f.puts "# Saleor Export Statistics"
          f.puts "# Generated at: #{Time.current}"
          f.puts "# Endpoint: #{endpoint}"
          f.puts ""
          result[:stats].each { |key, value| f.puts "#{key}: #{value}" }
        end
        puts "Statistics saved to: #{ENV['STATS_FILE']}"
      end
      
    else
      puts "\n💥 Export failed: #{result[:error]}"
      exit 1
    end
  end
  
  desc "Проверка подключения к Saleor API"
  task :test_connection => :environment do
    endpoint = ENV['SALEOR_ENDPOINT']
    token = ENV['SALEOR_TOKEN']
    
    unless endpoint && token
      puts "Error: Please set SALEOR_ENDPOINT and SALEOR_TOKEN environment variables"
      exit 1
    end
    
    puts "Testing connection to: #{endpoint}"
    
    exporter = SaleorProductExporter.new(endpoint, token)
    
    if exporter.test_connection
      puts "✓ Connection successful!"
      puts "✓ API is accessible and authentication is working"
    else
      puts "✗ Connection failed!"
      puts "✗ Please check your endpoint URL and authentication token"
      exit 1
    end
  end
  
  desc "Экспорт ограниченного количества продуктов для тестирования"
  task :export_sample => :environment do
    endpoint = ENV['SALEOR_ENDPOINT']
    token = ENV['SALEOR_TOKEN']
    limit = ENV['LIMIT']&.to_i || 5
    
    unless endpoint && token
      puts "Error: Please set SALEOR_ENDPOINT and SALEOR_TOKEN environment variables"
      exit 1
    end
    
    puts "\n📊 Exporting #{limit} sample products to test integration..."
    
    exporter = SaleorProductExporter.new(endpoint, token, {
      logger: Logger.new(STDOUT),
      batch_size: 5,
      delay: 0.5
    })
    
    result = exporter.export_all({
      limit: limit,
      export_categories: true,
      create_product_types: true
    })
    
    if result[:success]
      puts "\n🎉 Sample export completed!"
      puts "Exported #{result[:stats][:products_created]} products and #{result[:stats][:categories_created]} categories"
      puts "You can now check your Saleor admin panel to verify the import"
    else
      puts "\n💥 Sample export failed: #{result[:error]}"
      exit 1
    end
  end
  
  desc "Экспорт только категорий"
  task :export_categories => :environment do
    endpoint = ENV['SALEOR_ENDPOINT']
    token = ENV['SALEOR_TOKEN']
    
    unless endpoint && token
      puts "Error: Please set SALEOR_ENDPOINT and SALEOR_TOKEN environment variables"
      exit 1
    end
    
    exporter = SaleorProductExporter.new(endpoint, token, logger: Logger.new(STDOUT))
    
    puts "\n📋 Exporting categories only..."
    
    begin
      exporter.export_categories
      puts "\n✓ Categories export completed!"
    rescue => e
      puts "\n✗ Categories export failed: #{e.message}"
      exit 1
    end
  end
  
  desc "Получить статистику по продуктам в базе"
  task :stats => :environment do
    puts "\n📊 Rozario Database Statistics:\n"
    
    # Основная статистика
    puts "Products: #{Product.count}"
    puts "Categories: #{Category.count}"
    puts "Product Complects (variants): #{ProductComplect.count}"
    puts "Complect types: #{Complect.count}"
    
    # Продукты с комплектациями
    products_with_complects = Product.joins(:product_complects).distinct.count
    puts "Products with variants: #{products_with_complects}"
    
    # Категории
    root_categories = Category.where(parent_id: [0, nil]).count
    child_categories = Category.where.not(parent_id: [0, nil]).count
    puts "Root categories: #{root_categories}"
    puts "Child categories: #{child_categories}"
    
    # Топ категорий по количеству продуктов
    puts "\nTop 5 categories by product count:"
    Category.joins(:products)
            .group('categories.title')
            .order('count_products_id DESC')
            .limit(5)
            .count('products.id')
            .each { |name, count| puts "  #{name}: #{count} products" }
    
    # Типы комплектаций
    puts "\nComplect types:"
    Complect.all.each do |complect|
      count = ProductComplect.where(complect_id: complect.id).count
      puts "  #{complect.title} (#{complect.header}): #{count} variants"
    end
    
    # Продукты без категорий
    products_without_categories = Product.left_joins(:categories)
                                        .where(categories: { id: nil })
                                        .count
    if products_without_categories > 0
      puts "\n⚠️  Products without categories: #{products_without_categories}"
    end
    
    # Продукты без комплектаций
    products_without_complects = Product.left_joins(:product_complects)
                                       .where(product_complects: { id: nil })
                                       .count
    if products_without_complects > 0
      puts "⚠️  Products without variants: #{products_without_complects}"
    end
    
    puts "\n📄 Ready for export: #{products_with_complects} products with variants"
    puts ""
  end
end

desc "Show available Saleor export tasks"
task :saleor do
  puts "🌿 Saleor Export Tasks:"
  puts ""
  puts "  rake saleor:stats                    - Show database statistics"
  puts "  rake saleor:test_connection          - Test Saleor API connection"
  puts "  rake saleor:export_sample            - Export 5 sample products"
  puts "  rake saleor:export_categories        - Export categories only"
  puts "  rake saleor:export                   - Full export (products + categories)"
  puts ""
  puts "Environment variables:"
  puts "  SALEOR_ENDPOINT  - Saleor GraphQL endpoint (required)"
  puts "  SALEOR_TOKEN     - Authentication token (required)"
  puts "  LIMIT            - Limit number of products"
  puts "  PRODUCT_IDS      - Comma-separated product IDs"
  puts "  BATCH_SIZE       - Batch size (default: 10)"
  puts "  DELAY            - Delay between requests (default: 1)"
  puts "  DEBUG            - Enable debug logging"
  puts "  STATS_FILE       - Save statistics to file"
  puts ""
  puts "Examples:"
  puts "  rake saleor:test_connection SALEOR_ENDPOINT=https://mystore.saleor.cloud/graphql/ SALEOR_TOKEN=abc123"
  puts "  rake saleor:export_sample SALEOR_ENDPOINT=https://mystore.saleor.cloud/graphql/ SALEOR_TOKEN=abc123"
  puts "  rake saleor:export SALEOR_ENDPOINT=... SALEOR_TOKEN=... LIMIT=100"
end

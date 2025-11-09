#!/usr/bin/env ruby
# encoding: utf-8

# CLI утилита для экспорта данных в Saleor
# Использование:
#   ruby lib/saleor_export/export_cli.rb --help
#   ruby lib/saleor_export/export_cli.rb --endpoint https://your-saleor.com/graphql/ --token YOUR_TOKEN

require 'optparse'
require 'logger'
require_relative '../../config/boot' # Загружаем окружение Padrino
require_relative 'product_exporter'

class SaleorExportCLI
  
  def self.run(args = ARGV)
    options = parse_args(args)
    
    # Настройка логгера
    logger = Logger.new(options[:log_file] || STDOUT)
    logger.level = options[:debug] ? Logger::DEBUG : Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    
    # Проверка обязательных параметров
    if options[:endpoint].nil? || options[:token].nil?
      puts "Error: --endpoint and --token are required"
      puts "Use --help for more information"
      exit 1
    end
    
    # Создаем экспортер
    exporter = SaleorProductExporter.new(
      options[:endpoint], 
      options[:token], 
      {
        logger: logger,
        batch_size: options[:batch_size],
        delay: options[:delay]
      }
    )
    
    # Определяем параметры экспорта
    export_options = {
      export_categories: options[:categories],
      create_product_types: options[:product_types], 
      product_ids: options[:product_ids],
      limit: options[:limit]
    }
    
    logger.info "Starting Saleor export..."
    logger.info "Endpoint: #{options[:endpoint]}"
    logger.info "Options: #{export_options.inspect}"
    
    # Проверяем подключение если указано
    if options[:test_connection]
      logger.info "Testing connection..."
      if exporter.test_connection
        logger.info "✓ Connection successful"
        return
      else
        logger.error "✗ Connection failed"
        exit 1
      end
    end
    
    # Запускаем экспорт
    begin
      result = exporter.export_all(export_options)
      
      if result[:success]
        logger.info "🎉 Export completed successfully!"
        logger.info "Duration: #{result[:duration].round(2)} seconds"
        
        if options[:output_stats]
          save_stats_to_file(result[:stats], options[:output_stats])
        end
      else
        logger.error "💥 Export failed: #{result[:error]}"
        exit 1
      end
      
    rescue Interrupt
      logger.warn "Export interrupted by user"
      exit 130
    rescue => e
      logger.error "Unexpected error: #{e.message}"
      logger.error e.backtrace.join("\n") if options[:debug]
      exit 1
    end
  end
  
  private
  
  def self.parse_args(args)
    options = {
      batch_size: 10,
      delay: 1,
      categories: true,
      product_types: true
    }
    
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      
      opts.separator ""
      opts.separator "Required options:"
      
      opts.on("-e", "--endpoint URL", "Saleor GraphQL endpoint") do |url|
        options[:endpoint] = url
      end
      
      opts.on("-t", "--token TOKEN", "Authentication token") do |token|
        options[:token] = token
      end
      
      opts.separator ""
      opts.separator "Export options:"
      
      opts.on("--no-categories", "Skip categories export") do
        options[:categories] = false
      end
      
      opts.on("--no-product-types", "Skip product types creation") do
        options[:product_types] = false
      end
      
      opts.on("-p", "--products IDS", Array, "Export specific product IDs (comma-separated)") do |ids|
        options[:product_ids] = ids.map(&:to_i)
      end
      
      opts.on("-l", "--limit N", Integer, "Limit number of products to export") do |limit|
        options[:limit] = limit
      end
      
      opts.separator ""
      opts.separator "Performance options:"
      
      opts.on("-b", "--batch-size N", Integer, "Batch size for processing (default: 10)") do |size|
        options[:batch_size] = size
      end
      
      opts.on("-d", "--delay N", Float, "Delay between requests in seconds (default: 1)") do |delay|
        options[:delay] = delay
      end
      
      opts.separator ""
      opts.separator "Logging options:"
      
      opts.on("--log-file FILE", "Log to file instead of STDOUT") do |file|
        options[:log_file] = file
      end
      
      opts.on("--debug", "Enable debug logging") do
        options[:debug] = true
      end
      
      opts.on("--stats FILE", "Save export statistics to file") do |file|
        options[:output_stats] = file
      end
      
      opts.separator ""
      opts.separator "Utility options:"
      
      opts.on("--test-connection", "Test connection and exit") do
        options[:test_connection] = true
      end
      
      opts.on("-h", "--help", "Show this help") do
        puts opts
        exit
      end
      
      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  # Full export"
      opts.separator "  #{$0} --endpoint https://mystore.saleor.cloud/graphql/ --token abc123"
      opts.separator ""
      opts.separator "  # Export specific products only"
      opts.separator "  #{$0} -e https://mystore.saleor.cloud/graphql/ -t abc123 -p 1,2,3 --no-categories"
      opts.separator ""
      opts.separator "  # Test connection"
      opts.separator "  #{$0} -e https://mystore.saleor.cloud/graphql/ -t abc123 --test-connection"
      opts.separator ""
      opts.separator "  # With custom settings"
      opts.separator "  #{$0} -e URL -t TOKEN --batch-size 5 --delay 2 --log-file export.log"
      opts.separator ""
    end
    
    parser.parse!(args)
    options
  rescue OptionParser::InvalidOption => e
    puts "Error: #{e.message}"
    puts "Use --help for more information"
    exit 1
  end
  
  def self.save_stats_to_file(stats, filename)
    File.open(filename, 'w') do |f|
      f.puts "# Saleor Export Statistics"
      f.puts "# Generated at: #{Time.current}"
      f.puts ""
      stats.each do |key, value|
        f.puts "#{key}: #{value}"
      end
    end
  end
end

# Запуск CLI если файл вызывается напрямую
if __FILE__ == $0
  SaleorExportCLI.run(ARGV)
end

# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Основной раннер для всех тестов проекта Rozario Flowers

require 'pathname'

# TODO: После актуализации тестов можно добавить minitest-reporters

class TestRunner
  def self.run_all
    puts "🧪 Запуск всех тестов Rozario Flowers"
    puts "=" * 50
    
    # Запуск unit тестов
    puts "\n📋 Unit тесты:"
    run_tests_in_directory('tests/unit')
    
    # Запуск интеграционных тестов
    puts "\n🔗 Интеграционные тесты:"
    run_tests_in_directory('tests/integration')
    
    # Запуск утилит для анализа
    puts "\n🔧 Утилиты анализа:"
    run_analysis_tools
    
    puts "\n✅ Все тесты завершены!"
  end
  
  def self.run_unit_only
    puts "📋 Запуск только unit тестов"
    run_tests_in_directory('tests/unit')
  end
  
  def self.run_integration_only
    puts "🔗 Запуск только интеграционных тестов"
    run_tests_in_directory('tests/integration')
  end
  
  def self.run_order_products_only
    puts "🛍️ Запуск только тестов order_products"
    puts "  → Unit: order_products_structure_test.rb"
    system("ruby unit/order_products_structure_test.rb")
    puts "  → Integration: test_order_products_flow.rb"
    system("ruby integration/test_order_products_flow.rb")
    puts "  → Performance: order_products_performance_analysis.rb"
    system("ruby utils/order_products_performance_analysis.rb")
  end
  
  def self.run_1c_tests_only
    puts "🔄 Запуск только 1C Exchange тестов"
    puts "  → Compatibility: order_products_1c_compatibility_test.rb"
    system("ruby unit/order_products_1c_compatibility_test.rb")
    puts "  → Integration: test_1c_exchange_api.rb (обновлено под новую структуру)"
    system("ruby integration/test_1c_exchange_api.rb")
    puts "  ⚠️  Старые unit тесты требуют nokogiri и могут не работать:"
    puts "    gem install nokogiri && ruby unit/test_1c_exchange_unit.rb"
  end
  
  def self.run_email_tests_only
    puts "📧 Запуск только Email тестов"
    puts "  → Unit: smart_encoding_test.rb"
    system("ruby unit/smart_encoding_test.rb")
    puts "  → Unit: email_functionality_test.rb"
    system("ruby unit/email_functionality_test.rb")
    puts "  → Integration: test_email_order_integration.rb"
    system("ruby integration/test_email_order_integration.rb")
  end
  
  private
  
  def self.run_tests_in_directory(dir)
    return unless Dir.exist?(dir)
    
    # Ищем файлы по паттерну *test*.rb
    Dir.glob("#{dir}/*test*.rb").each do |test_file|
      puts "  → #{File.basename(test_file)}"
      begin
        # Запускаем каждый тест как отдельный процесс
        system("ruby #{test_file}")
      rescue => e
        puts "    ❌ Ошибка: #{e.message}"
      end
    end
  end
  
  def self.run_analysis_tools
    analysis_files = [
      'tests/utils/order_products_performance_analysis.rb'
    ]
    
    analysis_files.each do |tool_file|
      if File.exist?(tool_file)
        puts "  → #{File.basename(tool_file)}"
        system("ruby #{tool_file}")
      end
    end
  end
end

# Запуск в зависимости от аргументов
if ARGV.empty?
  TestRunner.run_all
else
  case ARGV[0]
  when 'unit'
    TestRunner.run_unit_only
  when 'integration'
    TestRunner.run_integration_only
  when 'order_products'
    TestRunner.run_order_products_only
  when '1c'
    TestRunner.run_1c_tests_only
  when 'email'
    TestRunner.run_email_tests_only
  else
    puts "Использование: ruby test_runner.rb [unit|integration|order_products|1c|email]"
    puts "  unit         - только unit тесты"
    puts "  integration  - только интеграционные тесты"
    puts "  order_products - тесты структуры order_products"
    puts "  1c           - тесты 1C Exchange API"
    puts "  email        - тесты email функциональности и smart encoding"
    exit 1
  end
end

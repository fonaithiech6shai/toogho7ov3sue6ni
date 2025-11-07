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
  else
    puts "Использование: ruby test_runner.rb [unit|integration|order_products]"
    puts "  unit         - только unit тесты"
    puts "  integration  - только интеграционные тесты"
    puts "  order_products - тесты структуры order_products"
    exit 1
  end
end

#!/usr/bin/env ruby
# encoding: utf-8

# Быстрый старт для экспорта в Saleor
# Использование: ruby lib/saleor_export/quick_start.rb

require_relative '../../config/boot'
require_relative 'product_exporter'
require 'io/console'

class SaleorQuickStart
  def self.run
    puts "\n🌿 Saleor Export - Quick Start"
    puts "=" * 50
    
    # 1. Показываем статистику базы данных
    show_database_stats
    
    # 2. Получаем настройки Saleor
    config = get_saleor_config
    return if config.nil?
    
    # 3. Тестируем подключение
    unless test_connection(config[:endpoint], config[:token])
      puts "❌ Не удалось подключиться к Saleor API"
      return
    end
    
    # 4. Выбираем режим экспорта
    export_mode = choose_export_mode
    return if export_mode.nil?
    
    # 5. Запускаем экспорт
    run_export(config, export_mode)
  end
  
  private
  
  def self.show_database_stats
    puts "\n📊 Статистика базы данных:"
    puts "-" * 30
    
    products_count = Product.count
    categories_count = Category.count
    complects_count = ProductComplect.count
    products_with_complects = Product.joins(:product_complects).distinct.count
    
    puts "● Продуктов: #{products_count}"
    puts "● Категорий: #{categories_count}"
    puts "● Вариантов: #{complects_count}"
    puts "● Продуктов с вариантами: #{products_with_complects}"
    
    if products_with_complects == 0
      puts "\n⚠️  Нет продуктов с вариантами для экспорта!"
      return false
    end
    
    puts "\n✅ Готово к экспорту: #{products_with_complects} продуктов"
    true
  end
  
  def self.get_saleor_config
    puts "\n🔗 Настройки Saleor:"
    puts "-" * 20
    
    print "Введите Saleor GraphQL endpoint: "
    endpoint = gets.chomp
    
    if endpoint.empty?
      puts "❌ Endpoint не может быть пустым"
      return nil
    end
    
    print "Введите токен аутентификации: "
    token = STDIN.noecho(&:gets).chomp
    puts # Новая строка после скрытого ввода
    
    if token.empty?
      puts "❌ Токен не может быть пустым"
      return nil
    end
    
    {
      endpoint: endpoint,
      token: token
    }
  end
  
  def self.test_connection(endpoint, token)
    puts "\n🔍 Тестируем подключение..."
    
    begin
      exporter = SaleorProductExporter.new(endpoint, token)
      if exporter.test_connection
        puts "✅ Подключение успешно!"
        return true
      else
        puts "❌ Ошибка подключения"
        return false
      end
    rescue => e
      puts "❌ Ошибка: #{e.message}"
      return false
    end
  end
  
  def self.choose_export_mode
    puts "\n🎁 Выберите режим экспорта:"
    puts "-" * 25
    puts "1. Тестовый (5 продуктов)"
    puts "2. Ограниченный (указать количество)"
    puts "3. Полный (все продукты)"
    puts "4. Отмена"
    
    print "\nВаш выбор (1-4): "
    choice = gets.chomp.to_i
    
    case choice
    when 1
      { mode: :sample }
    when 2
      print "Введите максимальное количество продуктов: "
      limit = gets.chomp.to_i
      
      if limit <= 0
        puts "❌ Некорректное количество"
        return nil
      end
      
      { mode: :limited, limit: limit }
    when 3
      puts "\n⚠️  Полный экспорт может занять несколько часов!"
      print "Продолжить? (y/N): "
      confirm = gets.chomp.downcase
      
      if confirm == 'y' || confirm == 'yes' || confirm == 'да'
        { mode: :full }
      else
        puts "❌ Отменено"
        nil
      end
    when 4
      puts "❌ Отменено"
      nil
    else
      puts "❌ Некорректный выбор"
      nil
    end
  end
  
  def self.run_export(config, export_mode)
    puts "\n🚀 Запуск экспорта..."
    puts "=" * 25
    
    # Настраиваем логгер
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%H:%M:%S')}] #{severity}: #{msg}\n"
    end
    
    # Создаем экспортер
    exporter = SaleorProductExporter.new(
      config[:endpoint],
      config[:token],
      {
        logger: logger,
        batch_size: export_mode[:mode] == :sample ? 5 : 10,
        delay: export_mode[:mode] == :sample ? 0.5 : 1
      }
    )
    
    # Определяем опции экспорта
    export_options = {
      export_categories: true,
      create_product_types: true
    }
    
    case export_mode[:mode]
    when :sample
      export_options[:limit] = 5
      puts "💡 Тестовый экспорт (5 продуктов)"
    when :limited
      export_options[:limit] = export_mode[:limit]
      puts "💡 Ограниченный экспорт (#{export_mode[:limit]} продуктов)"
    when :full
      puts "💡 Полный экспорт (все продукты)"
    end
    
    # Запускаем экспорт
    puts "⏱️  Начало: #{Time.current.strftime('%H:%M:%S')}"
    
    begin
      result = exporter.export_all(export_options)
      
      if result[:success]
        puts "\n🎉 Экспорт успешно завершен!"
        puts "⏱️  Продолжительность: #{result[:duration].round(2)} секунд"
        puts "\n📈 Результаты:"
        puts "● Категорий создано: #{result[:stats][:categories_created]}"
        puts "● Продуктов создано: #{result[:stats][:products_created]}"
        puts "● Вариантов создано: #{result[:stats][:variants_created]}"
        
        if result[:stats][:products_errors] > 0 || result[:stats][:categories_errors] > 0
          puts "\n⚠️  Ошибки:"
          puts "● Категории: #{result[:stats][:categories_errors]}"
          puts "● Продукты: #{result[:stats][:products_errors]}"
          puts "● Варианты: #{result[:stats][:variants_errors]}"
        end
        
        puts "\n💻 Проверьте результат в админке Saleor!"
      else
        puts "\n❌ Экспорт не удался: #{result[:error]}"
      end
      
    rescue Interrupt
      puts "\n\n⚠️  Экспорт прерван пользователем"
    rescue => e
      puts "\n❌ Неожиданная ошибка: #{e.message}"
    end
  end
end

# Запуск если файл вызывается напрямую
if __FILE__ == $0
  SaleorQuickStart.run
end

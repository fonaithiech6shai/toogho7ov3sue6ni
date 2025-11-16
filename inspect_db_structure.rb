#!/usr/bin/env ruby
# encoding: utf-8

# Загружаем окружение приложения
require File.expand_path('../config/boot', __FILE__)
require File.expand_path('../app/app', __FILE__)

puts "🔍 Исследование структуры базы данных Rozario"
puts "=" * 50

begin
  # Проверяем подключение к базе
  puts "📡 Проверка подключения к базе данных..."
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "✅ Подключение успешно!"
  
  # Исследуем структуру product_complects
  puts "\n📊 Структура таблицы product_complects:"
  columns = ActiveRecord::Base.connection.columns('product_complects')
  
  columns.each do |column|
    puts "   #{column.name.ljust(20)} | #{column.type.to_s.ljust(10)} | #{column.null ? 'NULL' : 'NOT NULL'} | #{column.default}"
  end
  
  # Проверяем наличие поля id_1C
  has_id_1c = columns.any? { |col| col.name == 'id_1C' }
  puts "\n🆔 Поле id_1C: #{has_id_1c ? '✅ Найдено' : '❌ Отсутствует'}"
  
  if has_id_1c
    # Проверяем сколько записей имеют заполненный id_1C
    total_complects = ProductComplect.count
    with_id_1c = ProductComplect.where.not(id_1C: nil).count
    
    puts "\n📈 Статистика по id_1C:"
    puts "   Всего комплектов: #{total_complects}"
    puts "   С заполненным id_1C: #{with_id_1c}"
    puts "   Процент заполненности: #{with_id_1c > 0 ? ((with_id_1c.to_f / total_complects * 100).round(2)) : 0}%"
    
    # Покажем несколько примеров
    puts "\n📋 Примеры записей с id_1C:"
    examples = ProductComplect.where.not(id_1C: nil).limit(5)
    examples.each_with_index do |pc, index|
      puts "   #{index + 1}. ID: #{pc.id}, id_1C: #{pc.id_1C}, Product: #{pc.product_id}, Complect: #{pc.complect_id}"
    end
    
  else
    puts "\n⚠️  Поле id_1C не найдено. Возможные варианты:"
    id_like_columns = columns.select { |col| col.name.downcase.include?('id') && col.name != 'id' }
    id_like_columns.each do |col|
      puts "   - #{col.name} (#{col.type})"
    end
  end
  
  # Исследуем связанные таблицы
  puts "\n🔗 Связанные таблицы:"
  
  # Products
  products_count = Product.count
  products_with_complects = Product.joins(:product_complects).distinct.count
  puts "   Products: #{products_count} (#{products_with_complects} имеют комплекты)"
  
  # Complects
  complects = Complect.all
  puts "   Complects: #{complects.count}"
  complects.each do |c|
    puts "     - #{c.title} (#{c.header})"
  end
  
rescue => e
  puts "❌ Ошибка подключения к базе данных:"
  puts "   #{e.message}"
  puts "\n💡 Убедитесь, что:"
  puts "   - Установлена переменная MYSQL_PASSWORD"
  puts "   - MySQL сервер запущен"
  puts "   - База данных admin_rozario_development доступна"
end

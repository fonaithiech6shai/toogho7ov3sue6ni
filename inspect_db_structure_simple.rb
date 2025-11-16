#!/usr/bin/env ruby
# encoding: utf-8

require 'mysql2'

# Конфигурация базы данных из database.rb
password = ENV['MYSQL_PASSWORD']

db_config = {
  'host' => '127.0.0.1',
  'port' => 3306,
  'username' => 'admin',
  'database' => 'admin_rozario_development',
  'password' => password
}

if password.nil?
  puts "❌ Не указан пароль для базы данных. Установите MYSQL_PASSWORD"
  exit 1
end

puts "🔍 Исследование структуры базы данных Rozario"
puts "=" * 50

begin
  # Подключаемся к базе данных
  client = Mysql2::Client.new(
    host: db_config['host'],
    port: db_config['port'],
    username: db_config['username'],
    password: password,
    database: db_config['database']
  )
  
  puts "✅ Подключение к базе успешно: #{db_config['database']}"
  
  # Получаем структуру таблицы product_complects
  puts "\n📊 Структура таблицы product_complects:"
  
  columns_result = client.query("DESCRIBE product_complects")
  columns = []
  
  columns_result.each do |row|
    columns << {
      name: row['Field'],
      type: row['Type'],
      null: row['Null'],
      key: row['Key'],
      default: row['Default']
    }
    puts "   #{row['Field'].ljust(20)} | #{row['Type'].ljust(15)} | #{row['Null'].ljust(3)} | #{row['Key']} | #{row['Default']}"
  end
  
  # Проверяем наличие поля id_1C
  has_id_1c = columns.any? { |col| col[:name] == 'id_1C' }
  puts "\n🆔 Поле id_1C: #{has_id_1c ? '✅ Найдено' : '❌ Отсутствует'}"
  
  if has_id_1c
    # Статистика по id_1C
    total_result = client.query("SELECT COUNT(*) as total FROM product_complects")
    total_complects = total_result.first['total']
    
    with_id_1c_result = client.query("SELECT COUNT(*) as count FROM product_complects WHERE id_1C IS NOT NULL AND id_1C != ''")
    with_id_1c = with_id_1c_result.first['count']
    
    puts "\n📈 Статистика по id_1C:"
    puts "   Всего комплектов: #{total_complects}"
    puts "   С заполненным id_1C: #{with_id_1c}"
    puts "   Процент заполненности: #{with_id_1c > 0 ? ((with_id_1c.to_f / total_complects * 100).round(2)) : 0}%"
    
    # Примеры записей
    if with_id_1c > 0
      puts "\n📋 Примеры записей с id_1C:"
      examples_result = client.query("SELECT id, id_1C, product_id, complect_id FROM product_complects WHERE id_1C IS NOT NULL AND id_1C != '' LIMIT 5")
      
      examples_result.each_with_index do |row, index|
        puts "   #{index + 1}. ID: #{row['id']}, id_1C: #{row['id_1C']}, Product: #{row['product_id']}, Complect: #{row['complect_id']}"
      end
    end
    
  else
    puts "\n⚠️  Поле id_1C не найдено. Доступные поля:"
    id_like_columns = columns.select { |col| col[:name].downcase.include?('id') && col[:name] != 'id' }
    id_like_columns.each do |col|
      puts "   - #{col[:name]} (#{col[:type]})"
    end
  end
  
  # Информация о связанных таблицах
  puts "\n🔗 Связанные таблицы:"
  
  # Количество продуктов
  products_result = client.query("SELECT COUNT(*) as count FROM products")
  products_count = products_result.first['count']
  
  products_with_complects_result = client.query("SELECT COUNT(DISTINCT p.id) as count FROM products p JOIN product_complects pc ON p.id = pc.product_id")
  products_with_complects = products_with_complects_result.first['count']
  
  puts "   Products: #{products_count} (#{products_with_complects} с комплектами)"
  
  # Комплекты
  complects_result = client.query("SELECT id, title, header FROM complects ORDER BY id")
  puts "   Complects: #{complects_result.count}"
  complects_result.each do |row|
    puts "     - #{row['title']} (#{row['header']})"
  end
  
  client.close
  
rescue Mysql2::Error => e
  puts "❌ Ошибка MySQL: #{e.message}"
  puts "\n💡 Проверьте:"
  puts "   - Пароль: MYSQL_PASSWORD=#{ENV['MYSQL_PASSWORD'] ? '[HIDDEN]' : 'NOT_SET'}"
  puts "   - База: #{db_config['database']}"
  puts "   - Хост: #{db_config['host'] || 'localhost'}"
  puts "   - Пользователь: #{db_config['username']}"
rescue => e
  puts "❌ Ошибка: #{e.message}"
  puts "   #{e.backtrace.first if e.backtrace}"
end

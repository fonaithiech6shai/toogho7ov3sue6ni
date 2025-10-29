#!/usr/bin/env ruby
# encoding: utf-8

# Скрипт для SQLite базы данных

require 'json'

class SmilesOrderIdProcessor
  
  def initialize
    @database_path = 'db/__rozario_production.db'
    
    unless File.exist?(@database_path)
      puts "✗ Файл базы данных не найден: #{@database_path}"
      exit 1
    end
  end
  
  def process_all_smiles
    puts "Скрипт обработки order_eight_digit_id для объектов smiles"
    puts "База данных: #{@database_path}"
    puts "=" * 60
    
    # Проверяем подключение к SQLite
    unless test_sqlite_connection
      puts "✗ Не удалось подключиться к SQLite"
      return
    end
    
    # Получаем количество smiles
    smiles_count = get_smiles_count
    if smiles_count == 0
      puts "Нет объектов smiles для обработки."
      return
    end
    
    puts "Найдено объектов smiles: #{smiles_count}"
    
    processed_count = 0
    updated_count = 0
    
    puts "\nНачинаем обработку..."
    
    # Получаем все smiles с NULL order_eight_digit_id
    smiles_to_process = get_smiles_with_null_order_id
    
    puts "Найдено smiles с NULL order_eight_digit_id: #{smiles_to_process.length}"
    
    if smiles_to_process.empty?
      puts "Все smiles уже имеют order_eight_digit_id. Обработка не требуется."
      return
    end
    
    smiles_to_process.each do |smile|
      processed_count += 1
      smile_id = smile['id']
      current_order_id = smile['order_eight_digit_id']
      
      puts "\nОбработка smile ID: #{smile_id} (#{processed_count}/#{smiles_to_process.length})"
      puts "  order_eight_digit_id = #{current_order_id.inspect} => генерируем новый ID"
      
      # Генерируем уникальный 8-значный номер
      new_eight_digit_id = generate_unique_eight_digit_id
      
      if new_eight_digit_id
        # Обновляем smile
        if update_smile_order_id(smile_id, new_eight_digit_id)
          puts "  ✓ Установлен order_eight_digit_id = #{new_eight_digit_id}"
          updated_count += 1
        else
          puts "  ✗ Ошибка обновления smile ID #{smile_id}"
        end
      else
        puts "  ✗ Не удалось сгенерировать уникальный ID (исчерпаны попытки)"
      end
      
      # Показываем прогресс
      if processed_count % 5 == 0
        puts "\n--- Прогресс: #{processed_count}/#{smiles_to_process.length} (обновлено: #{updated_count}) ---"
      end
    end
    
    puts "\n=== ЗАВЕРШЕНО ==="
    puts "Всего обработано: #{processed_count}"
    puts "Обновлено: #{updated_count}"
    puts "Пропущено: #{processed_count - updated_count}"
  end
  
  private
  
  def sqlite_command(query)
    "sqlite3 '#{@database_path}' \"#{query}\" 2>/dev/null"
  end
  
  def test_sqlite_connection
    result = `#{sqlite_command('SELECT 1 as test')}`
    return result.strip == '1'
  rescue
    return false
  end
  
  def get_smiles_count
    result = `#{sqlite_command('SELECT COUNT(*) FROM smiles')}`
    result.strip.to_i
  rescue
    return 0
  end
  
  def get_smiles_with_null_order_id
    # Получаем первые 20 smiles с NULL order_eight_digit_id
    query = "SELECT id, order_eight_digit_id FROM smiles WHERE order_eight_digit_id IS NULL LIMIT 20"
    result = `#{sqlite_command(query)}`
    
    return [] if result.strip.empty?
    
    result.strip.split("\n").map do |line|
      parts = line.split('|')
      {
        'id' => parts[0].to_i,
        'order_eight_digit_id' => parts[1] && parts[1] != '' ? parts[1] : nil
      }
    end
  rescue
    return []
  end
  
  def order_exists?(eight_digit_id)
    query = "SELECT COUNT(*) FROM orders WHERE eight_digit_id = #{eight_digit_id}"
    result = `#{sqlite_command(query)}`
    
    count = result.strip.to_i
    return count > 0
  rescue
    return false
  end
  
  def update_smile_order_id(smile_id, new_order_id)
    query = "UPDATE smiles SET order_eight_digit_id = #{new_order_id} WHERE id = #{smile_id}"
    result = `#{sqlite_command(query)}`
    return $?.success?
  rescue
    return false
  end
  
  def generate_unique_eight_digit_id
    max_attempts = 50
    attempts = 0
    
    loop do
      attempts += 1
      
      if attempts > max_attempts
        puts "    ✗ Превышено максимальное количество попыток (#{max_attempts})"
        return nil
      end
      
      # Шаг 12345: генерируем случайное 8-значное число
      x = rand(10_000_000..99_999_999)
      puts "    Попытка #{attempts}: сгенерирован ID = #{x}"
      
      # Проверяем существует ли объект orders с таким eight_digit_id
      if order_exists?(x)
        puts "      ✗ Order с eight_digit_id = #{x} уже существует => повторяем генерацию"
        next # Возвращаемся на шаг 12345
      else
        puts "      ✓ Order с eight_digit_id = #{x} не существует => используем этот ID"
        return x
      end
    end
  end
end

# Запуск скрипта
if __FILE__ == $0
  begin
    processor = SmilesOrderIdProcessor.new
    processor.process_all_smiles
  rescue => e
    puts "\n✗ ОБЩАЯ ОШИБКА: #{e.message}"
    puts "\nДетали ошибки:"
    puts e.backtrace.first(5).join("\n")
  end
  
  puts "\nСкрипт завершен."
end
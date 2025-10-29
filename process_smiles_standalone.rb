#!/usr/bin/env ruby
# encoding: utf-8

# Стандалонный скрипт без Bundler

begin
  require 'active_record'
  require 'mysql2'
rescue LoadError => e
  puts "Ошибка загрузки gem: #{e.message}"
  puts "Установите необходимые gems:"
  puts "gem install activerecord mysql2"
  exit 1
end

# Конфигурация базы данных
db_config = {
  adapter:   'mysql2',
  host:      '127.0.0.1',
  port:      3306,
  encoding:  'utf8',
  reconnect: true,
  database:  'admin_rozario_development',
  pool:      50,
  username:  'admin',
  password:  ENV['MYSQL_PASSWORD'].to_s
}

begin
  ActiveRecord::Base.establish_connection(db_config)
  # Проверяем подключение
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "✓ Подключение к базе данных успешно"
rescue => e
  puts "✗ Ошибка подключения к базе: #{e.message}"
  puts "Проверьте:"
  puts "- Переменная окружения MYSQL_PASSWORD"
  puts "- Доступ к базе admin_rozario_development"
  puts "- Запущен ли MySQL сервер"
  exit 1
end

# Определяем модели
class Smile < ActiveRecord::Base
  self.table_name = 'smiles'
end

class Order < ActiveRecord::Base
  self.table_name = 'orders'
end

class SmilesOrderIdProcessor
  
  def self.process_all_smiles
    puts "Скрипт обработки order_eight_digit_id для объектов smiles"
    puts "=" * 60
    
    begin
      # Получаем количество smiles
      smiles_count = Smile.count
      puts "Найдено объектов smiles: #{smiles_count}"
      
      if smiles_count == 0
        puts "Нет объектов для обработки."
        return
      end
      
    rescue => e
      puts "Ошибка при получении smiles: #{e.message}"
      puts "Проверьте, существует ли таблица 'smiles'"
      return
    end
    
    processed_count = 0
    updated_count = 0
    
    puts "\nНачинаем обработку..."
    
    # Перебираем все smiles по частям
    Smile.find_in_batches(batch_size: 50) do |smiles_batch|
      smiles_batch.each do |smile|
        processed_count += 1
        
        puts "\nОбработка smile ID: #{smile.id} (#{processed_count}/#{smiles_count})"
        
        # Получаем значение order_eight_digit_id
        current_order_id = smile.order_eight_digit_id
        
        if current_order_id.is_a?(Numeric) && !current_order_id.nil?
          puts "  order_eight_digit_id = #{current_order_id} (число) => continue"
          next # Переходим к следующему smile
        elsif current_order_id.nil?
          puts "  order_eight_digit_id = NULL => генерируем новый ID"
          
          # Генерируем уникальный 8-значный номер
          new_eight_digit_id = generate_unique_eight_digit_id
          
          if new_eight_digit_id
            # Обновляем smile
            begin
              smile.update_attribute(:order_eight_digit_id, new_eight_digit_id)
              puts "  ✓ Установлен order_eight_digit_id = #{new_eight_digit_id}"
              updated_count += 1
            rescue => e
              puts "  ✗ Ошибка сохранения: #{e.message}"
            end
          else
            puts "  ✗ Не удалось сгенерировать уникальный ID (исчерпаны попытки)"
          end
        else
          puts "  order_eight_digit_id = #{current_order_id.inspect} (неожиданное значение) => пропускаем"
        end
        
        # Показываем прогресс каждые 10 объектов
        if processed_count % 10 == 0
          puts "\n--- Прогресс: #{processed_count}/#{smiles_count} (обновлено: #{updated_count}) ---"
        end
      end
    end
    
    puts "\n=== ЗАВЕРШЕНО ==="
    puts "Всего обработано: #{processed_count}"
    puts "Обновлено: #{updated_count}"
    puts "Пропущено: #{processed_count - updated_count}"
  end
  
  private
  
  def self.generate_unique_eight_digit_id
    max_attempts = 100 # Уменьшаем количество попыток для теста
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
      begin
        if Order.exists?(eight_digit_id: x)
          puts "      ✗ Order с eight_digit_id = #{x} уже существует => повторяем генерацию"
          next # Возвращаемся на шаг 12345
        else
          puts "      ✓ Order с eight_digit_id = #{x} не существует => используем этот ID"
          return x
        end
      rescue => e
        puts "      ✗ Ошибка проверки Order: #{e.message}"
        puts "      → Продолжаем с допущением, что ID #{x} свободен"
        return x
      end
    end
  end
end

# Запуск скрипта
if __FILE__ == $0
  begin
    SmilesOrderIdProcessor.process_all_smiles
  rescue => e
    puts "\n✗ ОБЩАЯ ОШИБКА: #{e.message}"
    puts "\nДетали ошибки:"
    puts e.backtrace.first(5).join("\n")
  end
  
  puts "\nСкрипт завершен."
end
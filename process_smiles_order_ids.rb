#!/usr/bin/env ruby
# encoding: utf-8

# Скрипт для обработки smiles и генерации order_eight_digit_id

require_relative 'config/boot'

class SmilesOrderIdProcessor
  
  def self.process_all_smiles
    puts "Запуск обработки всех объектов smiles..."
    
    # Получаем все объекты smiles
    smiles_count = Smile.count
    puts "Найдено объектов smiles: #{smiles_count}"
    
    processed_count = 0
    updated_count = 0
    
    # Перебираем все smiles в цикле
    Smile.find_each do |smile|
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
          smile.order_eight_digit_id = new_eight_digit_id
          
          if smile.save
            puts "  ✓ Установлен order_eight_digit_id = #{new_eight_digit_id}"
            updated_count += 1
          else
            puts "  ✗ Ошибка сохранения: #{smile.errors.full_messages.join(', ')}"
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
    
    puts "\n=== ЗАВЕРШЕНО ==="
    puts "Всего обработано: #{processed_count}"
    puts "Обновлено: #{updated_count}"
    puts "Пропущено: #{processed_count - updated_count}"
  end
  
  private
  
  def self.generate_unique_eight_digit_id
    max_attempts = 1000 # Максимум попыток для избежания бесконечного цикла
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
      if Order.exists?(eight_digit_id: x)
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
  puts "Скрипт обработки order_eight_digit_id для объектов smiles"
  puts "=" * 60
  
  begin
    SmilesOrderIdProcessor.process_all_smiles
  rescue => e
    puts "\n✗ ОШИБКА: #{e.message}"
    puts e.backtrace.join("\n")
  end
  
  puts "\nСкрипт завершен."
end
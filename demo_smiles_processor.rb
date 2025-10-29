#!/usr/bin/env ruby
# encoding: utf-8

# Демонстрационный скрипт алгоритма обработки smiles

class DemoSmilesOrderIdProcessor
  
  def initialize
    # Мок данные для демонстрации
    @demo_smiles = [
      { id: 1, order_eight_digit_id: 12345678 },  # Уже есть номер
      { id: 2, order_eight_digit_id: nil },       # Нужно сгенерировать
      { id: 3, order_eight_digit_id: 87654321 },  # Уже есть номер
      { id: 4, order_eight_digit_id: nil },       # Нужно сгенерировать
      { id: 5, order_eight_digit_id: nil },       # Нужно сгенерировать
    ]
    
    # Мок данные для orders (существующие ID)
    @existing_order_ids = [12345678, 87654321, 11111111, 22222222, 33333333]
  end
  
  def process_all_smiles
    puts "Демонстрация алгоритма обработки smiles"
    puts "=" * 60
    
    puts "Начальные данные:"
    @demo_smiles.each do |smile|
      puts "  Smile ID: #{smile[:id]}, order_eight_digit_id: #{smile[:order_eight_digit_id] || 'NULL'}"
    end
    
    puts "\nСуществующие Order eight_digit_id: #{@existing_order_ids.join(', ')}"
    
    puts "\n" + "=" * 60
    puts "Начинаем обработку по алгоритму:"
    
    processed_count = 0
    updated_count = 0
    
    # Перебираем все smiles в цикле
    @demo_smiles.each do |smile|
      processed_count += 1
      
      puts "\nОбработка smile ID: #{smile[:id]} (#{processed_count}/#{@demo_smiles.length})"
      
      # Получаем значение order_eight_digit_id
      current_order_id = smile[:order_eight_digit_id]
      
      if current_order_id.is_a?(Numeric) && !current_order_id.nil?
        puts "  order_eight_digit_id = #{current_order_id} (число) => continue"
        next # Переходим к следующему smile
      elsif current_order_id.nil?
        puts "  order_eight_digit_id = NULL => генерируем новый ID"
        
        # Генерируем уникальный 8-значный номер
        new_eight_digit_id = generate_unique_eight_digit_id
        
        if new_eight_digit_id
          # Обновляем smile (демо)
          smile[:order_eight_digit_id] = new_eight_digit_id
          @existing_order_ids << new_eight_digit_id # Добавляем в список
          puts "  ✓ Установлен order_eight_digit_id = #{new_eight_digit_id}"
          updated_count += 1
        else
          puts "  ✗ Не удалось сгенерировать уникальный ID (исчерпаны попытки)"
        end
      else
        puts "  order_eight_digit_id = #{current_order_id.inspect} (неожиданное значение) => пропускаем"
      end
    end
    
    puts "\n" + "=" * 60
    puts "РЕЗУЛЬТАТ ОБРАБОТКИ:"
    puts "" 
    puts "Итоговые данные:"
    @demo_smiles.each do |smile|
      puts "  Smile ID: #{smile[:id]}, order_eight_digit_id: #{smile[:order_eight_digit_id]}"
    end
    
    puts "\nСтатистика:"
    puts "Всего обработано: #{processed_count}"
    puts "Обновлено: #{updated_count}"
    puts "Пропущено: #{processed_count - updated_count}"
    puts "" 
    puts "Новые eight_digit_id: #{@existing_order_ids - [12345678, 87654321, 11111111, 22222222, 33333333]}"
  end
  
  private
  
  def generate_unique_eight_digit_id
    max_attempts = 20 # Мало попыток для демо
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
      if @existing_order_ids.include?(x)
        puts "      ✗ Order с eight_digit_id = #{x} уже существует => повторяем генерацию"
        next # Возвращаемся на шаг 12345
      else
        puts "      ✓ Order с eight_digit_id = #{x} не существует => используем этот ID"
        return x
      end
    end
  end
end

# Запуск демо
if __FILE__ == $0
  puts "ДЕМОНСТРАЦИЯ АЛГОРИТМА ОБРАБОТКИ SMILES"
  puts "Это демо-скрипт с мок-данными для показа логики"
  
  begin
    demo = DemoSmilesOrderIdProcessor.new
    demo.process_all_smiles
  rescue => e
    puts "\n✗ Ошибка: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
  
  puts "\nДемо завершено."
end
# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки исправлений в логике Smile
require 'json'

class Object
  def present?
    !nil? && !empty?
  rescue
    !nil?
  end
end

class NilClass
  def present?
    false
  end
end

# Mock классы
class MockOrder
  attr_accessor :id, :eight_digit_id
  
  def initialize(id, eight_digit_id)
    @id = id
    @eight_digit_id = eight_digit_id
  end
  
  def self.find_by_eight_digit_id(eight_digit_id)
    return self.new(100, eight_digit_id) if eight_digit_id == 12345678
    nil
  end
end

class MockOrderProduct
  attr_accessor :product_id, :title, :price, :quantity, :typing, :base_id
  
  def initialize(product_id, title, price, quantity, typing = 'standard')
    @product_id = product_id
    @title = title
    @price = price
    @quantity = quantity
    @typing = typing
    @base_id = rand(1000)
  end
  
  def self.find_by_sql(query)
    # Проверяем, что используется правильный SQL
    puts "\n=== SQL Query Test ==="
    puts "Query: #{query}"
    
    if query.include?('WHERE order_id =')
      puts "❌ ERROR: Обнаружен неправильный SQL-запрос с 'WHERE order_id ='"
      puts "Должно быть: 'WHERE id =' (поле id является FK на orders.id)"
      return []
    elsif query.include?('WHERE id = 100')
      puts "✅ OK: SQL-запрос исправлен, возвращаем тестовые данные"
      return [
        self.new(123, 'Букет "Романтика"', 1500, 1, 'standard'),
        self.new(456, 'Открытка поздравительная', 100, 1, 'card')
      ]
    else
      puts "⚠️ WARNING: Неизвестный SQL-запрос"
      return []
    end
  end
  
  def respond_to?(method)
    method == :base_id ? true : super
  end
end

class MockProduct
  attr_accessor :id, :header
  
  def initialize(id, header)
    @id = id
    @header = header
  end
  
  def self.find_by_id(id)
    return self.new(123, 'Букет "Романтика" 15 роз') if id == 123
    return self.new(456, 'Поздравительная открытка') if id == 456
    nil
  end
end

class MockComplect
  attr_accessor :title
  
  def initialize(title)
    @title = title
  end
  
  def self.find_by_title(title)
    return self.new(title) if ['standard', 'card'].include?(title)
    nil
  end
end

# Тестовый класс Smile
class TestSmile
  attr_accessor :order_eight_digit_id, :json_order, :id
  
  def initialize(order_id = nil, json_data = nil, id = 1)
    @order_eight_digit_id = order_id
    @json_order = json_data
    @id = id
  end
  
  # Копия логики из модели Smile (order_products_for_display)
  def order_products_for_display
    return nil unless order_eight_digit_id.present?
    
    begin
      # Находим заказ по eight_digit_id
      order = MockOrder.find_by_eight_digit_id(order_eight_digit_id)
      return nil unless order
      
      # Получаем товары из заказа - тестируем правильную структуру БД
      cart_items = MockOrderProduct.find_by_sql("SELECT * FROM order_products WHERE order_id = #{order.id}")
      return nil if cart_items.empty?
      
      # Преобразуем в формат, совместимый с json_order
      result = {}
      cart_items.each_with_index do |item, index|
        begin
          product = MockProduct.find_by_id(item.product_id)
          complect = MockComplect.find_by_title(item.typing) if item.typing
          
          result[index.to_s] = {
            'id' => item.product_id.to_s,
            'complect' => item.typing || 'standard',
            'title' => item.title || (product ? product.header : "Товар не найден"),
            'price' => item.price,
            'quantity' => item.quantity,
            'base_id' => item.respond_to?(:base_id) ? item.base_id : nil,
            'product_exists' => !product.nil?
          }
        rescue => e
          result[index.to_s] = {
            'id' => item.product_id.to_s,
            'complect' => item.typing || 'standard',
            'title' => item.title || "Товар не найден",
            'price' => item.price,
            'quantity' => item.quantity,
            'base_id' => item.respond_to?(:base_id) ? item.base_id : nil,
            'product_exists' => false,
            'error' => e.message
          }
        end
      end
      
      result
      
    rescue => e
      nil
    end
  end
  
  # Копия логики из модели Smile (products_data)
  def products_data
    # Приоритет: данные из реального заказа
    order_data = order_products_for_display
    return order_data if order_data
    
    # Fallback: используем json_order
    begin
      return JSON.parse(json_order) if json_order.present?
    rescue => e
      # json_order не может быть распарсен
    end
    
    # Последний fallback
    {}
  end
  
  def using_order_data?
    order_eight_digit_id.present? && order_products_for_display.present?
  end
end

# Тест %main_product_name% логики
class TestSeoHelper
  def initialize(smile)
    @smile = smile
  end
  
  def process_main_product_name_variable(text)
    # Копия новой логики из seo_helper.rb
    main_product_name = ""
    begin
      # Используем новую логику products_data
      products_data = @smile.products_data
      
      if products_data && products_data.is_a?(Hash) && !products_data.empty?
        first_item = products_data['0'] || products_data[0]
        
        if first_item && first_item['title'] && !first_item['title'].to_s.strip.empty?
          main_product_name = first_item['title'].to_s
        elsif first_item && first_item['id']
          product_id = first_item['id'].to_i
          product = MockProduct.find_by_id(product_id)
          main_product_name = product.header.to_s if product && product.header && !product.header.to_s.strip.empty?
        end
      end
    rescue => e
      # В случае ошибки оставляем пустую строку
    end
    
    text.gsub(/%main_product_name%/, main_product_name)
  end
end

puts "=== Тест исправлений Smile ==="
puts

# Тест 1: Проверка SQL-запроса
puts "=== Тест 1: SQL-запросы ==="
smile = TestSmile.new(12345678, nil)
products_data = smile.order_products_for_display

if products_data && !products_data.empty?
  puts "✅ SQL-запросы работают корректно"
  puts "   Получено товаров: #{products_data.keys.size}"
  puts "   Первый товар: #{products_data['0']['title']}"
else
  puts "❌ SQL-запросы не работают"
end

puts

# Тест 2: %main_product_name% переменная
puts "=== Тест 2: %main_product_name% переменная ==="

# Тест с данными из заказа
smile_with_order = TestSmile.new(12345678, nil)
seo_helper = TestSeoHelper.new(smile_with_order)

test_text = "Фото доставки букета «%main_product_name%»"
processed_text = seo_helper.process_main_product_name_variable(test_text)

puts "   Исходный текст: #{test_text}"
puts "   Обработанный текст: #{processed_text}"

if processed_text.include?('Букет "Романтика"')
  puts "✅ %main_product_name% работает с данными из заказа"
else
  puts "❌ %main_product_name% не работает с данными из заказа"
end

puts

# Тест с старыми данными из json_order
smile_with_json = TestSmile.new(nil, '{"0": {"id": "777", "title": "JSON товар", "price": 1200}}')
seo_helper_json = TestSeoHelper.new(smile_with_json)

processed_text_json = seo_helper_json.process_main_product_name_variable(test_text)
puts "   Fallback к json_order: #{processed_text_json}"

if processed_text_json.include?('JSON товар')
  puts "✅ %main_product_name% работает с fallback к json_order"
else
  puts "❌ %main_product_name% не работает с fallback к json_order"
end

puts
puts "=== Тесты завершены ==="
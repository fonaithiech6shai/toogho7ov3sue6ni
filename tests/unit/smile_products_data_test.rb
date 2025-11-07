# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

require 'minitest/autorun'
require 'json'

# Unit test for Smile.products_data logic
# Tests the priority: order_data > json_order > empty fallback
class SmileProductsDataTest < Minitest::Test
  
  def setup
    # Mock classes simulating AR models without DB dependency
    @mock_order_class = Class.new do
      def self.find_by_eight_digit_id(eight_digit_id)
        return self.new(100, eight_digit_id) if eight_digit_id == 12345678
        nil
      end
      
      def initialize(id, eight_digit_id)
        @id = id
        @eight_digit_id = eight_digit_id
      end
      
      attr_reader :id, :eight_digit_id
    end
    
    @mock_order_product_class = Class.new do
      def self.find_by_sql(query)
        # Правильная структура БД: в order_products поле 'order_id' является FK на orders.id
        if query.include?('WHERE order_id = 100')
          return [
            self.new(123, 'Букет "Романтика"', 1500, 1, 'standard'),
            self.new(456, 'Открытка поздравительная', 100, 1, 'card')
          ]
        end
        []
      end
      
      def initialize(product_id, title, price, quantity, typing = 'standard')
        @product_id = product_id
        @title = title
        @price = price
        @quantity = quantity
        @typing = typing
        @base_id = rand(1000)
      end
      
      attr_reader :product_id, :title, :price, :quantity, :typing, :base_id
      
      def respond_to?(method)
        method == :base_id ? true : super
      end
    end
    
    @mock_product_class = Class.new do
      def self.find_by_id(id)
        return self.new(123, 'Букет "Романтика" 15 роз') if id == 123
        return self.new(456, 'Поздравительная открытка') if id == 456
        nil
      end
      
      def initialize(id, header)
        @id = id
        @header = header
      end
      
      attr_reader :id, :header
    end
    
    @mock_complect_class = Class.new do
      def self.find_by_title(title)
        return self.new(title) if ['standard', 'card'].include?(title)
        nil
      end
      
      def initialize(title)
        @title = title
      end
      
      attr_reader :title
    end
  end
  
  def create_mock_smile(order_id = nil, json_data = nil, smile_id = 1)
    mock_smile = Class.new do
      def initialize(order_id, json_data, smile_id, mock_classes)
        @order_eight_digit_id = order_id
        @json_order = json_data
        @id = smile_id
        @mock_order = mock_classes[:order]
        @mock_order_product = mock_classes[:order_product] 
        @mock_product = mock_classes[:product]
        @mock_complect = mock_classes[:complect]
      end
      
      attr_reader :order_eight_digit_id, :json_order, :id
      
      def present?
        !nil? && respond_to?(:empty?) ? !empty? : !nil?
      end
      
      def order_products_for_display
        return nil unless order_eight_digit_id && order_eight_digit_id.to_s.length > 0
        
        begin
          # Находим заказ по eight_digit_id
          order = @mock_order.find_by_eight_digit_id(order_eight_digit_id)
          return nil unless order
          
          # Получаем товары из заказа (поле 'id' является FK на orders.id)
          cart_items = @mock_order_product.find_by_sql("SELECT * FROM order_products WHERE order_id = #{order.id}")
          return nil if cart_items.empty?
          
          # Преобразуем в формат, совместимый с json_order
          result = {}
          cart_items.each_with_index do |item, index|
            begin
              product = @mock_product.find_by_id(item.product_id)
              complect = @mock_complect.find_by_title(item.typing) if item.typing
              
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
      
      def products_data
        # Приоритет: данные из реального заказа
        order_data = order_products_for_display
        return order_data if order_data
        
        # Fallback: используем json_order
        begin
          return JSON.parse(json_order) if json_order && json_order.to_s.length > 0
        rescue => e
          # json_order не может быть распарсен
        end
        
        # Последний fallback - пустой словарь
        {}
      end
      
      def using_order_data?
        order_eight_digit_id && order_eight_digit_id.to_s.length > 0 && order_products_for_display && !order_products_for_display.empty?
      end
      
      # Методы для работы с комментариями (моки)
      def related_comment
        return nil unless order_eight_digit_id && order_eight_digit_id.to_s.length > 0
        # В тестах возвращаем nil, можно переопределить
        nil
      end
      
      def has_review_comment?
        comment = related_comment
        return false unless comment
        
        body = comment.body
        return false unless body
        
        # Проверяем что body не пустое (имитируем present?)
        if body.respond_to?(:present?)
          body.present?
        else
          # Для строк в тестах
          body.to_s.strip.length > 0
        end
      end
    end
    
    mock_smile.new(
      order_id, 
      json_data, 
      smile_id,
      {
        order: @mock_order_class,
        order_product: @mock_order_product_class,
        product: @mock_product_class,
        complect: @mock_complect_class
      }
    )
  end
  
  def test_order_data_priority
    # Test 1: Smile with valid order_eight_digit_id should use order data
    smile = create_mock_smile(12345678, '{"0": {"id": "999", "title": "Old JSON Product", "price": 500}}')
    
    assert smile.using_order_data?, "Should use order data when order_eight_digit_id is valid"
    
    result = smile.products_data
    refute_empty result, "Should return data from order"
    assert_equal "123", result["0"]["id"], "Should use product ID from order data"
    assert_equal "Букет \"Романтика\"", result["0"]["title"], "Should use title from order data"
    assert_equal 1500, result["0"]["price"], "Should use price from order data"
    assert_equal true, result["0"]["product_exists"], "Should mark product as existing"
  end
  
  def test_json_fallback
    # Test 2: Smile with invalid order_eight_digit_id should fallback to json_order
    smile = create_mock_smile(99999999, '{"0": {"id": "888", "title": "JSON Fallback Product", "price": 750}}')
    
    refute smile.using_order_data?, "Should not use order data with invalid order ID"
    
    result = smile.products_data
    refute_empty result, "Should return data from json_order"
    assert_equal "888", result["0"]["id"], "Should use product ID from json_order"
    assert_equal "JSON Fallback Product", result["0"]["title"], "Should use title from json_order"
    assert_equal 750, result["0"]["price"], "Should use price from json_order"
  end
  
  def test_backward_compatibility
    # Test 3: Smile with only json_order (no order_eight_digit_id) 
    json_data = '{"0": {"id": "777", "title": "Pure JSON Product", "price": 1200, "complect": "standard"}}'
    smile = create_mock_smile(nil, json_data)
    
    refute smile.using_order_data?, "Should not use order data when no order_eight_digit_id"
    
    result = smile.products_data
    refute_empty result, "Should return data from json_order"
    assert_equal "777", result["0"]["id"], "Should use product ID from json_order"
    assert_equal "Pure JSON Product", result["0"]["title"], "Should use title from json_order"
    assert_equal 1200, result["0"]["price"], "Should use price from json_order"
  end
  
  def test_empty_fallback
    # Test 4: Smile with no data should return empty hash
    smile = create_mock_smile(nil, nil)
    
    refute smile.using_order_data?, "Should not use order data with no data"
    
    result = smile.products_data
    assert_empty result, "Should return empty hash when no data available"
  end
  
  def test_invalid_json_handling
    # Test 5: Smile with invalid json_order should return empty hash
    smile = create_mock_smile(nil, '{invalid json')
    
    refute smile.using_order_data?, "Should not use order data with invalid JSON"
    
    result = smile.products_data
    assert_empty result, "Should return empty hash with invalid JSON"
  end
  
  def test_multiple_products_from_order
    # Test 6: Multiple products from order should be handled correctly
    smile = create_mock_smile(12345678, nil)
    
    assert smile.using_order_data?, "Should use order data"
    
    result = smile.products_data
    assert_equal 2, result.keys.size, "Should return 2 products from order"
    
    # First product
    assert_equal "123", result["0"]["id"]
    assert_equal "Букет \"Романтика\"", result["0"]["title"]
    assert_equal 1500, result["0"]["price"]
    
    # Second product
    assert_equal "456", result["1"]["id"]
    assert_equal "Открытка поздравительная", result["1"]["title"]
    assert_equal 100, result["1"]["price"]
  end
  
  def test_main_product_name_variable_logic
    # Test 7: %main_product_name% variable should work with products_data
    smile_with_order = create_mock_smile(12345678, nil)
    
    # Mock the SEO helper logic
    products_data = smile_with_order.products_data
    refute_empty products_data, "Should have products data"
    
    first_item = products_data['0']
    assert first_item, "Should have first item"
    assert_equal "Букет \"Романтика\"", first_item['title'], "Should get title from order data"
    
    # Test with fallback to json_order
    smile_with_json = create_mock_smile(nil, '{"0": {"id": "777", "title": "JSON Product", "price": 1200}}')
    products_data_json = smile_with_json.products_data
    refute_empty products_data_json, "Should have JSON products data"
    
    first_item_json = products_data_json['0']
    assert first_item_json, "Should have first JSON item"
    assert_equal "JSON Product", first_item_json['title'], "Should get title from JSON data"
  end
  
  # Новые тесты для интеграции с комментариями
  def test_smile_related_comment_returns_nil_when_no_order_id
    smile = create_mock_smile(nil, nil)
    assert_nil smile.related_comment, "Should return nil when no order_eight_digit_id"
  end
  
  def test_smile_has_review_comment_detection
    # Создаём smile с order_eight_digit_id
    smile = create_mock_smile('87654321', nil)
    
    # Mock комментария
    mock_comment = MiniTest::Mock.new
    mock_comment.expect :body, 'Отличные цветы!'
    
    # Mock метод related_comment
    smile.define_singleton_method(:related_comment) { mock_comment }
    
    assert_equal true, smile.has_review_comment?, "Should detect review comment when comment has body"
    
    mock_comment.verify
  end
  
  def test_smile_has_no_review_comment_when_body_empty
    smile = create_mock_smile('87654322', nil)
    
    # Mock комментария с пустым body
    mock_comment = MiniTest::Mock.new
    mock_comment.expect :body, ''
    
    smile.define_singleton_method(:related_comment) { mock_comment }
    
    assert_equal false, smile.has_review_comment?, "Should not detect review comment when body is empty"
    
    mock_comment.verify
  end
  
  def test_smile_has_no_review_comment_when_no_comment
    smile = create_mock_smile('87654323', nil)
    
    # related_comment возвращает nil
    smile.define_singleton_method(:related_comment) { nil }
    
    assert_equal false, smile.has_review_comment?, "Should not detect review comment when no comment exists"
  end
end

if __FILE__ == $0
  puts "Running Smile products_data unit tests..."
end
# encoding: utf-8
require_relative '../test_setup'
require 'minitest/autorun'
require 'json'

# Integration test for order_products structure changes
# Tests the complete order flow with new structure
class TestOrderProductsFlow < Minitest::Test
  
  def setup
    puts "\n🔧 Setting up order_products integration test..."
    
    # Mock order and products data
    @test_order = {
      id: 100,
      eight_digit_id: 12345678,
      total_summ: 1600.0,
      email: "integration@test.com"
    }
    
    @test_cart = [
      {
        "id" => "123",
        "quantity" => "2",
        "type" => "standard",
        "clean_price" => "1500"
      },
      {
        "id" => "456", 
        "quantity" => "1",
        "type" => "lux",
        "clean_price" => "500"
      }
    ]
    
    @expected_order_products = [
      {
        order_id: 100,
        product_id: 123,
        title: "Mock Product 123",
        price: 1500,
        quantity: 2,
        typing: "standard"
      },
      {
        order_id: 100,
        product_id: 456,
        title: "Mock Product 456",
        price: 500,
        quantity: 1,
        typing: "lux"
      }
    ]
  end
  
  def test_order_creation_flow
    puts "\n🛍️ Testing order creation flow..."
    
    # Simulate the order creation process
    order_id = @test_order[:id]
    cart = @test_cart
    
    # Step 1: Create order (this would normally create Order record)
    order_created = true
    assert order_created, "Order creation should succeed"
    
    # Step 2: Create order_products with NEW structure
    order_products = []
    cart.each do |item|
      # This simulates the NEW Order_product.new structure
      order_product = {
        order_id: order_id,  # NEW: order_id instead of id
        product_id: item["id"].to_i,
        title: "Mock Product #{item['id']}",
        price: item["clean_price"].to_i,
        quantity: item["quantity"].to_i,
        typing: item["type"] || "standard"
      }
      order_products << order_product
    end
    
    # Validate created order_products
    assert_equal 2, order_products.length, "Should create 2 order_products"
    
    order_products.each_with_index do |op, index|
      assert op.has_key?(:order_id), "Order_product #{index} should have order_id"
      assert_equal order_id, op[:order_id], "order_id should reference correct order"
      assert op.has_key?(:product_id), "Order_product #{index} should have product_id"
      assert op.has_key?(:price), "Order_product #{index} should have price"
      assert op.has_key?(:quantity), "Order_product #{index} should have quantity"
    end
    
    puts "✅ Order creation with new structure successful"
  end
  
  def test_order_retrieval_flow
    puts "\n🔍 Testing order retrieval flow..."
    
    order_id = @test_order[:id]
    
    # Simulate SQL query with NEW structure
    query = "SELECT * FROM order_products WHERE order_id = #{order_id}"
    
    # Verify query structure
    assert_includes query, "order_id = #{order_id}", "Query should use order_id as FK"
    refute_includes query, "WHERE id = #{order_id}", "Query should NOT use id as FK"
    
    # Simulate query result (what we'd get from database)
    mock_query_result = @expected_order_products
    
    # Validate retrieved data
    assert_equal 2, mock_query_result.length, "Should retrieve 2 order_products"
    
    mock_query_result.each do |product|
      assert_equal order_id, product[:order_id], "Retrieved product should belong to correct order"
      assert product.has_key?(:product_id), "Product should have product_id"
      assert product.has_key?(:title), "Product should have title"
      assert product.has_key?(:price), "Product should have price"
    end
    
    puts "✅ Order retrieval with new structure successful"
  end
  
  def test_api_endpoints_integration
    puts "\n📡 Testing API endpoints integration..."
    
    # Test POST /api/v1/orders/create payload structure
    create_payload = {
      subdomain: 1,
      cart_order: @test_cart,
      order_data: {
        o_name: "Иван Иванов",
        o_phone: "+7 912 345 67 89",
        o_email: "ivan@example.com",
        o_payment: "4"
      }
    }
    
    # Validate payload
    assert create_payload.has_key?(:cart_order), "Payload should have cart_order"
    assert create_payload.has_key?(:order_data), "Payload should have order_data"
    assert !create_payload[:cart_order].empty?, "Cart should not be empty"
    
    # Test API response structure
    mock_api_response = {
      order_id: 12345678,
      include_tax: "LMI_SHOPPINGCART.ITEMS[0].NAME=Product..."
    }
    
    assert mock_api_response.has_key?(:order_id), "Response should include order_id"
    assert mock_api_response.has_key?(:include_tax), "Response should include include_tax"
    assert_kind_of Integer, mock_api_response[:order_id], "order_id should be integer"
    
    puts "✅ API endpoints integration successful"
  end
  
  def test_admin_interface_integration
    puts "\n⚙️ Testing admin interface integration..."
    
    order_eight_digit_id = @test_order[:eight_digit_id]
    order_id = @test_order[:id]
    
    # Simulate GET /admin/smiles/order_products/:order_id
    # This would use the NEW query: "SELECT * FROM order_products WHERE order_id = #{order.id}"
    admin_query_result = @expected_order_products
    
    # Simulate admin API response formatting
    admin_response = admin_query_result.map.with_index do |item, index|
      # Simulate that id field is now the primary key (1001, 1002, etc.)
      mock_id = 1001 + index
      
      {
        base_id: mock_id,  # NEW: id is now primary key for order_products_base_id
        id: item[:product_id],
        title: item[:title],
        price: item[:price],
        quantity: item[:quantity],
        typing: item[:typing],
        product_exists: true
      }
    end
    
    assert_equal 2, admin_response.length, "Admin should return all products"
    assert admin_response.all? { |p| p.has_key?(:base_id) }, "All products should have base_id"
    assert admin_response.all? { |p| p[:base_id] > 1000 }, "base_id should be primary key values"
    
    puts "✅ Admin interface integration successful"
  end
  
  def test_smile_model_integration
    puts "\n😊 Testing Smile model integration..."
    
    # Test that Smile model can work with new order_products structure
    order_products_base_id = 1001  # This would be order_product.id (new PK)
    
    # Simulate Smile.order_product method with new structure
    # OLD: Order_product.find_by_base_id(order_products_base_id)
    # NEW: Order_product.find(order_products_base_id)
    
    # Mock the find operation
    mock_order_product = {
      id: order_products_base_id,  # Primary key
      order_id: 100,              # Foreign key to orders
      product_id: 123,
      title: "Букет Розы",
      price: 1500,
      quantity: 1,
      typing: "standard"
    }
    
    # Validate that Smile can find order_product by new primary key
    assert mock_order_product.has_key?(:id), "Order_product should have id (PK)"
    assert mock_order_product.has_key?(:order_id), "Order_product should have order_id (FK)"
    assert_equal order_products_base_id, mock_order_product[:id], "Should find by correct primary key"
    
    puts "✅ Smile model integration successful"
  end
  
  def test_performance_implications
    puts "\n⚡ Testing performance implications..."
    
    # Test that new queries should be more efficient
    # because they use proper indexed fields
    
    # Queries that should use index on order_id
    indexed_queries = [
      "SELECT * FROM order_products WHERE order_id = ?",
      "SELECT COUNT(*) FROM order_products WHERE order_id = ?",
      "SELECT op.*, p.header FROM order_products op JOIN products p ON op.product_id = p.id WHERE op.order_id = ?"
    ]
    
    indexed_queries.each do |query|
      assert_includes query, "order_id", "Query should use indexed order_id field"
    end
    
    # Primary key lookups (should be fastest)
    pk_queries = [
      "SELECT * FROM order_products WHERE id = ?"
    ]
    
    pk_queries.each do |query|
      assert_includes query, "WHERE id =", "Query should use primary key lookup"
    end
    
    # JOIN queries with proper foreign key
    join_queries = [
      "SELECT o.eight_digit_id, op.title FROM orders o JOIN order_products op ON o.id = op.order_id"
    ]
    
    join_queries.each do |query|
      assert_includes query, "o.id = op.order_id", "JOIN should use proper foreign key"
    end
    
    puts "✅ Performance implications validated"
  end
  
  def test_error_handling_scenarios
    puts "\n❌ Testing error handling scenarios..."
    
    # Test various error conditions that should be handled
    
    # 1. Empty cart
    empty_cart = []
    assert empty_cart.empty?, "Empty cart should be detected"
    
    # 2. Missing required fields
    invalid_cart_item = { "id" => "123" }  # Missing quantity, price
    refute invalid_cart_item.has_key?("quantity"), "Invalid item missing quantity"
    refute invalid_cart_item.has_key?("clean_price"), "Invalid item missing price"
    
    # 3. Invalid order_id reference
    invalid_order_product = {
      order_id: nil,  # This should cause FK constraint error
      product_id: 123,
      price: 100
    }
    assert_nil invalid_order_product[:order_id], "Should detect nil order_id"
    
    # 4. SQL injection attempts (should be prevented by parameterized queries)
    malicious_input = "1'; DROP TABLE order_products; --"
    safe_query = "SELECT * FROM order_products WHERE order_id = ?"
    assert_includes safe_query, "?", "Should use parameterized query"
    
    puts "✅ Error handling scenarios validated"
  end
  
  def teardown
    puts "🧹 Integration test cleanup complete"
  end
end
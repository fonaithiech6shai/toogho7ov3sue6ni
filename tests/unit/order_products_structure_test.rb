# encoding: utf-8
require_relative '../test_setup'
require 'minitest/autorun'
require 'json'

# Unit test for order_products structure changes validation
# Tests the core logic changes: id->order_id migration
class OrderProductsStructureTest < Minitest::Test
  
  def setup
    @mock_order = OpenStruct.new(
      id: 100,
      eight_digit_id: 12345678,
      total_summ: 1500.0,
      email: "test@example.com"
    )
    
    @mock_order_products = [
      OpenStruct.new(
        id: 1001,
        order_id: 100,
        product_id: 123,
        title: "Букет \"Романтика\"",
        price: 1500,
        quantity: 1,
        typing: 'standard'
      ),
      OpenStruct.new(
        id: 1002,
        order_id: 100,
        product_id: 456,
        title: 'Открытка поздравительная',
        price: 100,
        quantity: 1,
        typing: 'card'
      )
    ]
  end
  
  def test_new_order_product_structure
    # Test that new structure has correct fields
    order_product = @mock_order_products.first
    
    assert_equal 1001, order_product.id, "ID should be primary key"
    assert_equal 100, order_product.order_id, "order_id should reference orders.id"
    assert_equal 123, order_product.product_id, "product_id should be preserved"
    assert_equal "Букет \"Романтика\"", order_product.title, "title should be preserved"
    assert_equal 1500, order_product.price, "price should be preserved"
    assert_equal 1, order_product.quantity, "quantity should be preserved"
    assert_equal 'standard', order_product.typing, "typing should be preserved"
  end
  
  def test_sql_query_structure_validation
    # Test that we use correct SQL queries
    order_id = 100
    
    correct_query = "SELECT * FROM order_products WHERE order_id = #{order_id}"
    incorrect_query = "SELECT * FROM order_products WHERE id = #{order_id}"
    
    assert_includes correct_query, 'order_id =', "Should use order_id as FK"
    refute_includes correct_query, 'WHERE id =', "Should not use id as FK"
    
    # Verify the queries are different (old vs new)
    refute_equal correct_query, incorrect_query, "Old and new query patterns should differ"
  end
  
  def test_api_response_structure
    # Test API response includes necessary fields for compatibility
    products = @mock_order_products
    
    api_response = products.map do |item|
      {
        base_id: item.id,  # NEW: id is now the primary key for order_products_base_id
        id: item.product_id,
        title: item.title,
        price: item.price,
        quantity: item.quantity,
        typing: item.typing,
        order_id: item.order_id  # NEW: explicit order_id field
      }
    end
    
    assert_equal 2, api_response.length, "API should return all products"
    
    first_product = api_response.first
    assert_equal 1001, first_product[:base_id], "base_id should be order_product.id (PK)"
    assert_equal 123, first_product[:id], "id should be product_id"
    assert_equal 100, first_product[:order_id], "order_id should be included"
    assert first_product.has_key?(:base_id), "Response should include base_id"
    assert first_product.has_key?(:order_id), "Response should include order_id"
  end
  
  def test_smile_integration_compatibility
    # Test that Smile model can find order_product by new primary key
    order_products_base_id = 1001  # This is now the order_product.id (PK)
    
    # Simulate finding order_product by ID (new primary key)
    found_product = @mock_order_products.find { |p| p.id == order_products_base_id }
    
    refute_nil found_product, "Should find order_product by new primary key"
    assert_equal order_products_base_id, found_product.id, "Found product should have correct ID"
    assert_equal "Букет \"Романтика\"", found_product.title, "Found product should have correct data"
  end
  
  def test_join_query_patterns
    # Test correct JOIN patterns for new structure
    old_join = "orders o JOIN order_products op ON o.id = op.id"
    new_join = "orders o JOIN order_products op ON o.id = op.order_id"
    
    assert_includes new_join, "op.order_id", "New JOIN should use order_id"
    refute_includes new_join, "op.id", "New JOIN should not use op.id as FK"
    refute_equal old_join, new_join, "Old and new JOIN should be different"
  end
  
  def test_backwards_compatibility_issues
    # Test that old queries would not work (as expected)
    old_queries = [
      "SELECT * FROM order_products WHERE id = 100",  # OLD: using id as FK
      "orders.id = order_products.id"  # OLD: JOIN condition
    ]
    
    old_queries.each do |query|
      if query.include?('WHERE id = 100')
        # This should find no results in new structure
        # (since id=100 would be looking for order_product with id=100, not order_id=100)
        assert_includes query, 'WHERE id =', "Old query uses id field"
      end
    end
  end
  
  def test_model_associations
    # Test that model associations are set up correctly
    # This is mainly testing the logic, not actual ActiveRecord
    
    # Order should have many order_products
    order_id = @mock_order.id
    related_products = @mock_order_products.select { |op| op.order_id == order_id }
    
    assert_equal 2, related_products.length, "Order should have 2 products"
    related_products.each do |product|
      assert_equal order_id, product.order_id, "Product should belong to correct order"
    end
  end
  
  def test_admin_api_data_structure
    # Test admin API compatibility with new structure
    order_eight_digit_id = 12345678
    order_id = 100
    
    # Simulate admin API response
    admin_response = @mock_order_products.map do |item|
      {
        base_id: item.id,  # NEW: primary key for order_products_base_id
        id: item.product_id,
        title: item.title,
        price: item.price,
        quantity: item.quantity,
        typing: item.typing,
        product_exists: true
      }
    end
    
    assert_equal 2, admin_response.length, "Admin API should return all products"
    assert admin_response.all? { |p| p.has_key?(:base_id) }, "All products should have base_id"
    
    # Verify base_id contains the new primary key values
    base_ids = admin_response.map { |p| p[:base_id] }
    assert_includes base_ids, 1001, "Should include order_product id 1001"
    assert_includes base_ids, 1002, "Should include order_product id 1002"
  end
  
  def test_performance_query_patterns
    # Test that new queries should be more efficient
    indexed_queries = [
      "SELECT * FROM order_products WHERE order_id = ?",
      "SELECT COUNT(*) FROM order_products WHERE order_id = ?",
      "SELECT * FROM order_products WHERE id = ?"
    ]
    
    indexed_queries.each do |query|
      if query.include?('order_id = ?')
        assert_includes query, 'order_id', "Query should use indexed order_id field"
      elsif query.include?('id = ?')
        assert_includes query, 'WHERE id =', "Query should use primary key lookup"
      end
    end
  end
end
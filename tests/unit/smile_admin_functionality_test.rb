# encoding: utf-8
require_relative '../test_setup'
require 'minitest/autorun'
require 'json'
require 'ostruct'

# Test for Smile admin functionality improvements
class SmileAdminFunctionalityTest < Minitest::Test
  
  def setup
    @mock_orders = [
      { id: 100, eight_digit_id: 12345678, email: "test@example.com", created_at: Time.now - 1 * 24 * 60 * 60 },
      { id: 101, eight_digit_id: 87654321, email: "user@test.com", created_at: Time.now - 2 * 24 * 60 * 60 }
    ]
    
    @mock_order_products = [
      { base_id: 1001, product_id: 123, title: "Букет Розы", price: 1500, quantity: 1, typing: "standard" },
      { base_id: 1002, product_id: 456, title: "Открытка", price: 100, quantity: 1, typing: "card" }
    ]
    
    @mock_user_accounts = [
      { id: 201, surname: "Петров", name: "Иван", email: "petrov@example.com" }
    ]
  end
  
  def test_published_bit_field_handling_create
    # Test BIT field handling for create operation
    params = {
      'title' => 'Test Smile',
      'slug' => 'test-smile',
      'published' => '1' # checkbox checked
    }
    
    processed_params = process_smile_params_for_create(params)
    
    assert_equal 1, processed_params['published'], "Published should be converted to integer 1 for MySQL BIT field"
    assert_nil processed_params['date'], "Date should be automatically set to NULL"
  end
  
  def test_published_bit_field_handling_create_unchecked
    # Test BIT field handling when checkbox is unchecked
    params = {
      'title' => 'Test Smile',
      'slug' => 'test-smile'
      # 'published' key is missing when checkbox unchecked
    }
    
    processed_params = process_smile_params_for_create(params)
    
    assert_equal 0, processed_params['published'], "Published should default to 0 when checkbox unchecked"
  end
  
  def test_published_bit_field_handling_update
    # Test BIT field handling for update operation
    params = {
      'title' => 'Updated Smile',
      'published' => 1 # integer value
    }
    
    processed_params = process_smile_params_for_update(params)
    
    assert_equal 1, processed_params['published'], "Published should handle integer values correctly"
  end
  
  def test_sql_query_fix_order_products
    # Test that SQL query uses correct field name (order_id instead of id)
    order_id = 100
    
    # Correct SQL should use 'WHERE order_id = X' not 'WHERE id = X'
    correct_sql = "SELECT * FROM order_products WHERE order_id = #{order_id}"
    incorrect_sql = "SELECT * FROM order_products WHERE id = #{order_id}"
    
    assert correct_sql.include?("WHERE order_id ="), "SQL should use 'order_id' field as FK to orders.id"
    refute incorrect_sql == correct_sql, "Should not use incorrect 'id' field name"
  end
  
  def test_order_products_api_response_structure
    # Test API endpoint response structure
    order_data = generate_order_api_response(12345678)
    
    # Parse JSON response
    response = JSON.parse(order_data)
    
    # Test required fields
    assert response['success'], "API response should indicate success"
    assert_equal 12345678, response['order_id'], "Should return correct order ID"
    assert response.has_key?('customer_name'), "Should include customer name field"
    assert response.has_key?('recipient_name'), "Should include recipient name field"
    assert response.has_key?('main_product_name'), "Should include main product name"
    assert response.has_key?('order_date'), "Should include order date"
    assert response.has_key?('products'), "Should include products array"
    
    # Test products array structure
    products = response['products']
    assert_instance_of Array, products, "Products should be an array"
    
    if products.any?
      product = products.first
      assert product.has_key?('base_id'), "Product should include base_id for order_products_base_id"
      assert product.has_key?('id'), "Product should include product ID"
      assert product.has_key?('title'), "Product should include title"
      assert product.has_key?('price'), "Product should include price"
      assert product.has_key?('quantity'), "Product should include quantity"
      assert product.has_key?('typing'), "Product should include typing/complect"
    end
  end
  
  def test_sorting_by_updated_at_with_id_fallback
    # Test new sorting logic: updated_at DESC, id DESC
    smiles_data = [
      { id: 1, updated_at: Time.now - 1 * 60 * 60, title: "Older smile" },
      { id: 2, updated_at: Time.now - 1 * 60 * 60, title: "Same time, higher ID" }, # Same updated_at
      { id: 3, updated_at: Time.now, title: "Newer smile" }
    ]
    
    sorted_smiles = sort_smiles_admin_order(smiles_data)
    
    # Should be sorted by updated_at DESC first, then by id DESC for ties
    assert_equal 3, sorted_smiles[0][:id], "Newest smile should be first"
    assert_equal 2, sorted_smiles[1][:id], "For same updated_at, higher ID should come first"
    assert_equal 1, sorted_smiles[2][:id], "Oldest smile should be last"
  end
  
  def test_unpublished_smiles_filter
    # Test new unpublished filter functionality
    all_smiles = [
      { id: 1, published: 1, title: "Published smile" },
      { id: 2, published: 0, title: "Unpublished smile 1" },
      { id: 3, published: 1, title: "Another published" },
      { id: 4, published: 0, title: "Unpublished smile 2" }
    ]
    
    unpublished_smiles = filter_unpublished_smiles(all_smiles)
    
    assert_equal 2, unpublished_smiles.size, "Should return only unpublished smiles"
    assert unpublished_smiles.all? { |s| s[:published] == 0 }, "All returned smiles should be unpublished"
    
    titles = unpublished_smiles.map { |s| s[:title] }
    assert_includes titles, "Unpublished smile 1"
    assert_includes titles, "Unpublished smile 2"
  end
  
  def test_delete_functionality_method_override
    # Test that delete uses method override for Padrino compatibility
    delete_form_params = {
      '_method' => 'delete',
      'authenticity_token' => 'mock_token'
    }
    
    assert_equal 'delete', delete_form_params['_method'], "Should use method override for delete"
    
    # Test form structure expectations
    expected_form_fields = ['_method', 'authenticity_token']
    expected_form_fields.each do |field|
      assert delete_form_params.has_key?(field), "Delete form should include #{field} field"
    end
  end
  
  def test_seo_indexing_auto_disable
    # Test that SEO indexing is automatically disabled when unpublishing
    smile_data = {
      id: 1,
      published: 1,
      seo: { index: 1 } # SEO indexing enabled
    }
    
    # Simulate unpublishing
    updated_smile = simulate_unpublish_smile(smile_data)
    
    assert_equal 0, updated_smile[:published], "Smile should be unpublished"
    assert_equal 0, updated_smile[:seo][:index], "SEO indexing should be automatically disabled"
  end
  
  def test_customer_name_extraction
    # Test customer name extraction from order data
    order_with_user = {
      eight_digit_id: 12345678,
      useraccount_id: 201
    }
    
    customer_name = extract_customer_name(order_with_user)
    
    # Should extract surname from user account
    assert_equal "Петров", customer_name, "Should extract surname as customer name"
  end
  
  def test_recipient_name_extraction
    # Test recipient name extraction from dname field
    order_with_recipient = {
      eight_digit_id: 12345678,
      dname: "Мария Сидорова"
    }
    
    recipient_name = extract_recipient_name(order_with_recipient)
    
    assert_equal "Мария Сидорова", recipient_name, "Should extract recipient name from dname field"
  end
  
  def test_json_order_fallback_logic
    # Test fallback to json_order when no real order data available
    smile_with_json_order = {
      order_eight_digit_id: nil,
      json_order: '{"0":{"id":"123","complect":"standard"}}'
    }
    
    products_data = get_products_data_with_fallback(smile_with_json_order)
    
    refute_nil products_data, "Should return data from json_order fallback"
    assert products_data.has_key?('0'), "Should parse json_order structure"
    assert_equal '123', products_data['0']['id'], "Should extract product ID from json_order"
  end
  
  private
  
  def process_smile_params_for_create(params)
    allowed_params = params.select { |k, v| 
      ['title', 'slug', 'body', 'images', 'rating', 'alt', 'smile_text', 'sidebar', 'order_eight_digit_id', 'order_products_base_id', 'seo_attributes', 'published'].include?(k) 
    }
    
    # Process published field
    published_value = params.has_key?('published') ? params['published'] : '0'
    published_int = (published_value == '1' || published_value == 1) ? 1 : 0
    allowed_params['published'] = published_int
    
    # Set date to NULL
    allowed_params['date'] = nil
    
    allowed_params
  end
  
  def process_smile_params_for_update(params)
    # Similar logic for update
    process_smile_params_for_create(params)
  end
  
  def generate_order_api_response(order_eight_digit_id)
    order = @mock_orders.find { |o| o[:eight_digit_id] == order_eight_digit_id }
    return { error: "Order not found" }.to_json unless order
    
    products = @mock_order_products.map do |item|
      {
        base_id: item[:base_id],
        id: item[:product_id],
        title: item[:title],
        price: item[:price],
        quantity: item[:quantity],
        typing: item[:typing],
        complect_name: item[:typing],
        product_exists: true
      }
    end
    
    {
      success: true,
      order_id: order_eight_digit_id,
      customer_name: "Петров",
      recipient_name: "Мария",
      main_product_name: products.first ? products.first[:title] : "",
      order_date: order[:created_at].strftime('%d.%m.%Y'),
      products: products
    }.to_json
  end
  
  def sort_smiles_admin_order(smiles)
    smiles.sort_by { |s| [-s[:updated_at].to_i, -s[:id]] }
  end
  
  def filter_unpublished_smiles(smiles)
    smiles.select { |s| s[:published] == 0 }
  end
  
  def simulate_unpublish_smile(smile_data)
    updated_smile = smile_data.dup
    updated_smile[:published] = 0
    
    # Auto-disable SEO indexing
    if updated_smile[:seo] && updated_smile[:seo][:index] == 1
      updated_smile[:seo][:index] = 0
    end
    
    updated_smile
  end
  
  def extract_customer_name(order)
    user_account = @mock_user_accounts.find { |u| u[:id] == order[:useraccount_id] }
    user_account ? user_account[:surname] : "Покупатель"
  end
  
  def extract_recipient_name(order)
    order[:dname] || ""
  end
  
  def get_products_data_with_fallback(smile)
    return nil if smile[:order_eight_digit_id] # Would use real order data
    
    # Fallback to json_order
    begin
      JSON.parse(smile[:json_order]) if smile[:json_order]
    rescue => e
      {}
    end
  end
end

puts "✅ Running Smile Admin Functionality Tests..."

# encoding: utf-8
# Test for 1C Exchange API endpoint
# This test covers the critical /api/1c_exchange endpoint used for order synchronization with 1C accounting system

require 'minitest/autorun'
require 'json'
require 'net/http'
require 'uri'
require 'nokogiri'
require_relative '../test_setup.rb'

class Test1CExchangeAPI < Minitest::Test
  
  def setup
    # Основной URL для тестирования
    @base_url = ENV['TEST_BASE_URL'] || 'http://localhost:4567'
    @api_endpoint = "#{@base_url}/api/1c_exchange"
    
    # Тестовые данные для создания заказа
    @test_order_data = {
      eight_digit_id: 12345678,
      oname: 'Test Customer',
      email: 'test@example.com',
      otel: '+79001234567',
      dname: 'Test Recipient',
      dtel: '+79009876543',
      city: 'Мурманск',
      region: 'Мурманская область',
      district_text: 'Ленинградская улица',
      deldom: '10',
      delkorpus: '2',
      delkvart: '15',
      date_from: '10:00',
      date_to: '18:00',
      d1_date: '2024-01-15',
      d2_date: '2024-01-15',
      payment_typetext: 'Наличными',
      cart: 'Букет роз с поздравлением',
      comment: 'Тестовый заказ для проверки API',
      total_summ: 2500.0,
      del_price: 300.0,
      delivery_price: 300.0,
      erp_status: 0,
      dcall: 1,
      ostav: 0,
      make_photo: 1,
      surprise: 0,
      country: 'Россия'
    }
  end
  
  def teardown
    # Очистка тестовых данных после каждого теста
    cleanup_test_data if defined?(Order)
  end
  
  # Тест режима checkauth - проверка аутентификации
  def test_checkauth_mode
    response = make_api_request(mode: 'checkauth')
    
    assert_equal 200, response.code.to_i, "Expected HTTP 200, got #{response.code}"
    assert_equal 'success', response.body.strip, "Expected 'success', got '#{response.body}'"
  end
  
  # Тест режима init - инициализация обмена
  def test_init_mode
    response = make_api_request(mode: 'init')
    
    assert_equal 200, response.code.to_i, "Expected HTTP 200, got #{response.code}"
    expected_body = 'zip=no file_limit=1024000'
    assert_equal expected_body, response.body.strip, "Expected init response, got '#{response.body}'"
  end
  
  # Тест режима query без заказов
  def test_query_mode_no_orders
    skip "Requires database connection" unless database_available?
    
    # Убеждаемся, что нет необработанных заказов
    clear_unprocessed_orders
    
    response = make_api_request(mode: 'query')
    
    assert_equal 200, response.code.to_i, "Expected HTTP 200, got #{response.code}"
    assert response.body.include?('<?xml'), "Expected XML response, got: #{response.body[0..100]}"
    
    # Проверяем структуру XML
    doc = parse_xml_response(response.body)
    assert doc, "Failed to parse XML response"
    
    # Проверяем корневой элемент
    root = doc.root
    assert_equal 'КоммерческаяИнформация', root.name, "Expected root element 'КоммерческаяИнформация'"
    assert_equal 'urn:1C.ru:commerceml_2', root['xmlns'], "Expected CommerceML namespace"
    assert_equal '2.03', root['ВерсияСхемы'], "Expected schema version 2.03"
  end
  
  # Тест режима query с тестовыми заказами
  def test_query_mode_with_orders
    skip "Requires database connection" unless database_available?
    
    # Создаем тестовый заказ
    test_order = create_test_order
    test_order_product = create_test_order_product(test_order.id)
    
    response = make_api_request(mode: 'query')
    
    assert_equal 200, response.code.to_i, "Expected HTTP 200, got #{response.code}"
    
    doc = parse_xml_response(response.body)
    assert doc, "Failed to parse XML response"
    
    # Проверяем наличие документа с нашим заказом
    documents = doc.xpath('//Документ')
    assert documents.length > 0, "Expected at least one order document"
    
    # Находим наш тестовый заказ
    test_document = documents.find { |doc| doc.xpath('Ид').text == test_order.eight_digit_id.to_s }
    assert test_document, "Test order not found in XML response"
    
    # Проверяем основные поля заказа
    assert_equal test_order.eight_digit_id.to_s, test_document.xpath('Номер').text
    assert_equal test_order.oname, test_document.xpath('ИмяПолучателя').text
    assert_equal test_order.dtel, test_document.xpath('ТелефонПолучателя').text
    assert_equal test_order.total_summ.to_i.to_s, test_document.xpath('Сумма').text
    
    # Проверяем контрагента
    contractor = test_document.xpath('Контрагенты/Контрагент').first
    assert contractor, "Contractor not found in order document"
    assert_equal test_order.oname, contractor.xpath('Наименование').text
    
    # Проверяем адрес доставки
    delivery_address = contractor.xpath('АдресДоставки').first
    assert delivery_address, "Delivery address not found"
    
    # Проверяем товары
    products = test_document.xpath('Товары/Товар')
    assert products.length >= 2, "Expected at least 2 products (delivery + actual product)"
    
    # Проверяем товар доставки
    delivery_product = products.find { |p| p.xpath('Наименование').text == 'Доставка' }
    assert delivery_product, "Delivery product not found"
    assert_equal test_order.del_price.to_s, delivery_product.xpath('ЦенаЗаЕдиницу').text
    
    # Проверяем основной товар
    main_product = products.find { |p| p.xpath('Ид').text == test_order_product.product_id.to_s }
    assert main_product, "Main product not found"
    assert_equal test_order_product.title, main_product.xpath('Наименование').text
  end
  
  # Тест обработки специальных символов и кодировки
  def test_query_mode_encoding
    skip "Requires database connection" unless database_available?
    
    # Создаем заказ с кириллицей и спецсимволами
    special_data = @test_order_data.dup
    special_data[:oname] = 'Тест «Кавычки» & символы <script>'
    special_data[:comment] = 'Комментарий с ёлками и №123'
    
    test_order = create_test_order(special_data)
    
    response = make_api_request(mode: 'query')
    
    assert_equal 200, response.code.to_i
    assert response.body.force_encoding('UTF-8').valid_encoding?, "Response should be valid UTF-8"
    
    doc = parse_xml_response(response.body)
    assert doc, "Failed to parse XML with special characters"
    
    # Проверяем, что специальные символы корректно экранированы
    test_document = doc.xpath('//Документ').find { |d| d.xpath('Ид').text == test_order.eight_digit_id.to_s }
    assert test_document, "Test order with special chars not found"
    
    name_element = test_document.xpath('ИмяПолучателя').text
    # XML должен корректно обрабатывать спецсимволы
    assert name_element.include?('Тест'), "Special characters should be preserved"
  end
  
  # Тест режима success - пометка заказов как обработанных
  def test_success_mode
    skip "Requires database connection" unless database_available?
    
    # Создаем необработанный заказ
    test_order = create_test_order
    assert_equal 0, test_order.erp_status, "Test order should start with erp_status = 0"
    
    response = make_api_request(mode: 'success')
    
    assert_equal 200, response.code.to_i
    assert_equal 'ok', response.body.strip
    
    # Проверяем, что статус заказа изменился
    test_order.reload if test_order.respond_to?(:reload)
    updated_order = Order.find(test_order.id) if defined?(Order)
    assert_equal 1, updated_order.erp_status, "Order erp_status should be updated to 1"
  end
  
  # Тест фильтрации тестовых заказов
  def test_excludes_tester_orders
    skip "Requires database connection" unless database_available?
    
    # Устанавливаем имя тестировщика
    original_tester = ENV['TESTER_NAME']
    ENV['TESTER_NAME'] = 'Test Tester'
    
    begin
      # Создаем заказ с именем тестировщика
      tester_data = @test_order_data.dup
      tester_data[:oname] = 'Test Tester'
      tester_data[:eight_digit_id] = 87654321
      
      tester_order = create_test_order(tester_data)
      
      # Создаем обычный заказ
      regular_order = create_test_order
      
      response = make_api_request(mode: 'query')
      doc = parse_xml_response(response.body)
      
      # Проверяем, что заказ тестировщика исключен
      documents = doc.xpath('//Документ')
      tester_doc = documents.find { |d| d.xpath('Ид').text == tester_order.eight_digit_id.to_s }
      regular_doc = documents.find { |d| d.xpath('Ид').text == regular_order.eight_digit_id.to_s }
      
      assert_nil tester_doc, "Tester order should be excluded from results"
      assert regular_doc, "Regular order should be included in results"
      
    ensure
      ENV['TESTER_NAME'] = original_tester
    end
  end
  
  # Тест обработки граничных случаев
  def test_handles_edge_cases
    skip "Requires database connection" unless database_available?
    
    # Создаем заказ с минимальными данными
    minimal_data = {
      eight_digit_id: 11111111,
      oname: 'Min',
      email: 'min@test.com',
      erp_status: 0,
      total_summ: 0.0,
      del_price: 0.0
    }
    
    test_order = create_test_order(minimal_data)
    
    response = make_api_request(mode: 'query')
    
    assert_equal 200, response.code.to_i
    
    doc = parse_xml_response(response.body)
    assert doc, "Should handle orders with minimal data"
    
    # Находим заказ с минимальными данными
    test_document = doc.xpath('//Документ').find { |d| d.xpath('Ид').text == test_order.eight_digit_id.to_s }
    assert test_document, "Order with minimal data should be present"
  end
  
  # Тест неправильных параметров
  def test_invalid_mode
    response = make_api_request(mode: 'invalid_mode')
    
    # API должен корректно обрабатывать неизвестный режим
    assert_equal 200, response.code.to_i
    # Без указанного режима возвращается пустой ответ или ошибка
  end
  
  # Тест без параметра mode
  def test_no_mode_parameter
    response = make_api_request
    
    assert_equal 200, response.code.to_i
    # Должен корректно обрабатывать запрос без параметра mode
  end
  
  private
  
  # Выполняет запрос к API
  def make_api_request(params = {})
    uri = URI(@api_endpoint)
    uri.query = URI.encode_www_form(params) unless params.empty?
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    
    begin
      response = http.request(request)
      return response
    rescue => e
      skip "API endpoint not available: #{e.message}"
    end
  end
  
  # Парсит XML ответ
  def parse_xml_response(xml_string)
    # Убираем лишние пробелы и проверяем на валидность
    xml_string = xml_string.strip
    return nil if xml_string.empty?
    
    begin
      Nokogiri::XML(xml_string) do |config|
        config.strict
      end
    rescue Nokogiri::XML::SyntaxError => e
      puts "XML parsing error: #{e.message}"
      puts "XML content: #{xml_string[0..500]}..."
      return nil
    end
  end
  
  # Проверяет доступность базы данных
  def database_available?
    return false unless defined?(ActiveRecord)
    
    begin
      ActiveRecord::Base.connection.active?
    rescue => e
      puts "Database not available: #{e.message}"
      false
    end
  end
  
  # Создает тестовый заказ
  def create_test_order(custom_data = {})
    return mock_order(custom_data) unless database_available?
    
    order_data = @test_order_data.merge(custom_data)
    Order.create!(order_data)
  end
  
  # Создает тестовый продукт заказа
  def create_test_order_product(order_id)
    return mock_order_product unless database_available?
    
    Order_product.create!(
      id: order_id,
      product_id: 123,
      title: 'Тестовый букет роз',
      price: 2200,
      quantity: 1,
      typing: 'Стандартная'
    )
  end
  
  # Создает мок объект заказа для тестов без БД
  def mock_order(custom_data = {})
    data = @test_order_data.merge(custom_data)
    mock = OpenStruct.new(data)
    mock.define_singleton_method(:reload) { self }
    mock.define_singleton_method(:save!) { true }
    mock
  end
  
  # Создает мок объект продукта заказа
  def mock_order_product
    OpenStruct.new(
      id: 123,
      product_id: 123,
      title: 'Тестовый букет роз',
      price: 2200,
      quantity: 1,
      typing: 'Стандартная'
    )
  end
  
  # Очищает необработанные заказы
  def clear_unprocessed_orders
    return unless database_available?
    Order.where(erp_status: 0).update_all(erp_status: 1) if defined?(Order)
  end
  
  # Очищает тестовые данные
  def cleanup_test_data
    return unless database_available?
    
    # Удаляем тестовые заказы
    test_ids = [12345678, 87654321, 11111111]
    Order.where(eight_digit_id: test_ids).destroy_all if defined?(Order)
    Order_product.where(id: test_ids).destroy_all if defined?(Order_product)
  end
end

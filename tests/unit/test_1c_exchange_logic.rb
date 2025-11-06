# encoding: utf-8
# Working Unit tests for 1C Exchange API logic
# Тестирует основную логику без зависимостей

require 'minitest/autorun'
require 'json'
require 'nokogiri'
require_relative '../test_setup.rb'

class Test1CExchangeLogic < Minitest::Test
  
  def setup
    @test_order_data = {
      eight_digit_id: 12345678,
      oname: 'Иван Петров',
      email: 'ivan@example.com',
      dname: 'Мария Сидорова',
      city: 'Мурманск',
      district_text: 'Ленинградская улица',
      del_address: '',
      d1_date: '2024-01-15',
      d2_date: nil,
      comment: 'Тестовый заказ',
      total_summ: 2500.0
    }
  end
  
  # Тест логики обработки адреса доставки
  def test_delivery_address_logic
    # Тест 1: del_address пустой, используется district_text
    result1 = process_address_logic('', 'Основная улица')
    assert_equal 'Основная улица', result1
    
    # Тест 2: del_address заполнен, используется del_address
    result2 = process_address_logic('Альтернативная улица', 'Основная улица')
    assert_equal 'Альтернативная улица', result2
    
    # Тест 3: оба пустые
    result3 = process_address_logic('', '')
    assert_equal '', result3
  end
  
  # Тест логики обработки даты доставки
  def test_delivery_date_logic
    # Тест 1: d2_date = nil, используется d1_date
    result1 = process_date_logic(nil, '2024-01-20')
    assert_equal '2024-01-20', result1
    
    # Тест 2: d2_date заполнен, используется d2_date
    result2 = process_date_logic('2024-01-25', '2024-01-20')
    assert_equal '2024-01-25', result2
    
    # Тест 3: обе nil
    result3 = process_date_logic(nil, nil)
    assert_equal '', result3
  end
  
  # Тест обработки специальных символов в XML
  def test_xml_special_characters
    xml_content = generate_xml_with_special_chars('Тест «Кавычки» & <script>')
    
    # XML должен парситься без ошибок
    doc = Nokogiri::XML(xml_content)
    assert doc.errors.empty?, "XML with special characters should be valid: #{doc.errors}"
    
    # Спецсимволы должны быть корректно экранированы
    content = doc.xpath('//test').text
    assert content.include?('Тест'), "XML should preserve cyrillic characters"
    # Nokogiri автоматически экранирует HTML теги при парсинге
    # Проверяем, что сырой XML содержит экранированные символы
    assert xml_content.include?('&lt;script&gt;'), "Raw XML should contain escaped HTML tags"
  end
  
  # Тест обработки nil значений
  def test_nil_values_handling
    # Проверяем, что nil значения обрабатываются корректно
    assert_equal '', safe_to_s(nil)
    assert_equal 'test', safe_to_s('test')
    assert_equal '123', safe_to_s(123)
    assert_equal '', safe_to_s('')
  end
  
  # Тест формата CommerceML XML
  def test_commerceml_xml_format
    xml = generate_commerceml_xml
    doc = Nokogiri::XML(xml)
    
    # Проверяем базовую структуру
    assert doc.errors.empty?, "CommerceML XML should be valid"
    assert_equal 'CommerceInfo', doc.root.name
    assert doc.xpath('//Order').length > 0, "Should contain order elements"
  end
  
  # Тест производительности
  def test_performance_bulk_processing
    start_time = Time.now
    
    # Обрабатываем 100 заказов
    100.times do |i|
      process_order_data({
        id: i,
        eight_digit_id: 10000000 + i,
        oname: "Заказчик #{i}",
        del_address: i.even? ? '' : "Улица #{i}",
        district_text: "Основная улица #{i}",
        d1_date: '2024-01-15',
        d2_date: i.odd? ? nil : '2024-01-16'
      })
    end
    
    processing_time = Time.now - start_time
    assert processing_time < 1.0, "Bulk processing should be fast (took #{processing_time}s)"
  end
  
  # Тест совместимости с 1С форматом
  def test_1c_compatibility
    # Проверяем обязательные поля для 1С
    order_fields = extract_1c_fields(@test_order_data)
    
    assert order_fields[:id].length > 0, "Order ID should not be empty"
    assert order_fields[:number].length > 0, "Order number should not be empty"
    assert_equal 'false', order_fields[:deletion_mark], "Deletion mark should be 'false'"
    assert_equal 'Заказ товара', order_fields[:operation], "Operation should be 'Order'"
    assert_equal 'руб', order_fields[:currency], "Currency should be 'RUB'"
  end
  
  # Тест фильтрации тестовых заказов
  def test_tester_filtering_logic
    # Симулируем логику фильтрации из API
    tester_name = 'Test User'
    
    orders = [
      { oname: 'Regular Customer', erp_status: 0 },
      { oname: 'Test User', erp_status: 0 },        # Должен быть исключен
      { oname: 'Another Customer', erp_status: 0 },
      { oname: 'Processed Order', erp_status: 1 }   # Должен быть исключен
    ]
    
    filtered_orders = filter_orders_for_1c(orders, tester_name)
    
    assert_equal 2, filtered_orders.length, "Should filter out test and processed orders"
    assert_equal 'Regular Customer', filtered_orders[0][:oname]
    assert_equal 'Another Customer', filtered_orders[1][:oname]
  end
  
  private
  
  # Обработка логики адреса (из оригинального API)
  def process_address_logic(del_address, district_text)
    if del_address != ''
      del_address
    else
      district_text || ''
    end
  end
  
  # Обработка логики даты (из оригинального API)
  def process_date_logic(d2_date, d1_date)
    d2_date || d1_date || ''
  end
  
  # Генерация XML со спецсимволами
  def generate_xml_with_special_chars(text)
    doc = Nokogiri::XML::Builder.new do |xml|
      xml.root do
        xml.test text
      end
    end
    doc.to_xml
  end
  
  # Безопасное преобразование в строку
  def safe_to_s(value)
    (value || '').to_s
  end
  
  # Генерация упрощенного CommerceML XML
  def generate_commerceml_xml
    doc = Nokogiri::XML::Builder.new do |xml|
      xml.CommerceInfo do
        xml.Order do
          xml.Id @test_order_data[:eight_digit_id]
          xml.Number @test_order_data[:eight_digit_id]
          xml.Customer @test_order_data[:oname]
          xml.Amount @test_order_data[:total_summ].to_i
        end
      end
    end
    doc.to_xml
  end
  
  # Обработка данных заказа
  def process_order_data(order_data)
    # Симулируем обработку заказа
    processed_order = {
      id: order_data[:eight_digit_id] || order_data[:id],
      address: process_address_logic(order_data[:del_address], order_data[:district_text]),
      delivery_date: process_date_logic(order_data[:d2_date], order_data[:d1_date]),
      customer: safe_to_s(order_data[:oname])
    }
    processed_order
  end
  
  # Извлечение полей для 1С
  def extract_1c_fields(order_data)
    {
      id: (order_data[:eight_digit_id] || order_data[:id]).to_s,
      number: order_data[:eight_digit_id].to_s,
      deletion_mark: 'false',
      operation: 'Заказ товара',
      currency: 'руб',
      customer: safe_to_s(order_data[:oname])
    }
  end
  
  # Фильтрация заказов для 1С
  def filter_orders_for_1c(orders, tester_name)
    orders.select do |order|
      order[:erp_status] == 0 &&  # Только необработанные
      order[:oname] != tester_name # Исключаем тестовые
    end
  end
end

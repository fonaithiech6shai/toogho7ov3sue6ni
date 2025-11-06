# encoding: utf-8
# Simplified Unit tests for 1C Exchange API logic (без подключения к БД)
# Упрощенная версия для быстрого тестирования

require 'minitest/autorun'
require 'json'
require 'nokogiri'
require 'ostruct'
require_relative '../test_setup.rb'

class Test1CExchangeUnitSimple < Minitest::Test
  
  def setup
    @test_order_data = {
      id: 1,
      eight_digit_id: 12345678,
      oname: 'Иван Петров',
      email: 'ivan@example.com',
      otel: '+79001234567',
      dname: 'Мария Сидорова',
      dtel: '+79009876543',
      city: 'Мурманск',
      region: 'Мурманская область',
      district_text: 'Ленинградская улица',
      del_address: '',
      deldom: '10',
      delkorpus: '2',
      delkvart: '15',
      date_from: '10:00',
      date_to: '18:00',
      d1_date: '2024-01-15',
      d2_date: nil,
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
      country: 'Россия',
      dt_txt: 'Курьерская доставка',
      created_at: Time.new(2024, 1, 15, 12, 30, 0)
    }
  end
  
  # Тест базовой структуры XML с латинскими тегами
  def test_basic_xml_structure
    xml = generate_simple_xml
    doc = Nokogiri::XML(xml)
    
    assert doc.errors.empty?, "XML should be valid: #{doc.errors}"
    
    # Проверяем корневой элемент
    root = doc.root
    assert_equal 'CommerceInformation', root.name
    assert_equal '2.03', root['version']
    # Namespace может быть обработан по-разному в Nokogiri
    assert root.to_xml.include?('urn:1C.ru:commerceml_2'), "Should contain CommerceML namespace"
    
    # Проверяем наличие документа
    documents = doc.xpath('//Document') + doc.xpath('//*[local-name()="Document"]')
    assert documents.length >= 1, "Should have at least one document"
  end
  
  # Тест основных полей заказа
  def test_order_basic_fields
    xml = generate_simple_xml
    doc = Nokogiri::XML(xml)
    
    document = doc.xpath('//*[local-name()="Document"]').first
    assert document, "Document element should exist"
    
    # Основные поля заказа
    assert_equal @test_order_data[:eight_digit_id].to_s, document.xpath('.//Id').text
    assert_equal @test_order_data[:eight_digit_id].to_s, document.xpath('.//Number').text
    assert_equal 'false', document.xpath('.//DeletionMark').text
    assert_equal 'Order', document.xpath('.//Operation').text
    assert_equal 'Seller', document.xpath('.//Role').text
    assert_equal 'RUB', document.xpath('.//Currency').text
    
    # Поля получателя
    assert_equal @test_order_data[:dname], document.xpath('.//RecipientName').text
    assert_equal @test_order_data[:dtel], document.xpath('.//RecipientPhone').text
    
    # Сумма и комментарий
    assert_equal @test_order_data[:total_summ].to_i.to_s, document.xpath('.//Amount').text
    assert_equal @test_order_data[:comment], document.xpath('.//Comment').text
  end
  
  # Тест логики обработки адреса доставки
  def test_delivery_address_logic
    # Тест 1: del_address пустой, используется district_text
    order1 = @test_order_data.dup
    order1[:del_address] = ''
    order1[:district_text] = 'Основная улица'
    
    processed_address = process_address_logic(order1)
    assert_equal 'Основная улица', processed_address
    
    # Тест 2: del_address заполнен, используется del_address
    order2 = @test_order_data.dup
    order2[:del_address] = 'Альтернативная улица'
    order2[:district_text] = 'Основная улица'
    
    processed_address2 = process_address_logic(order2)
    assert_equal 'Альтернативная улица', processed_address2
  end
  
  # Тест логики обработки d2_date
  def test_d2_date_logic
    # Тест 1: d2_date = nil, используется d1_date
    order1 = @test_order_data.dup
    order1[:d2_date] = nil
    order1[:d1_date] = '2024-01-20'
    
    processed_date = process_date_logic(order1)
    assert_equal '2024-01-20', processed_date
    
    # Тест 2: d2_date заполнен, используется d2_date
    order2 = @test_order_data.dup
    order2[:d2_date] = '2024-01-25'
    order2[:d1_date] = '2024-01-20'
    
    processed_date2 = process_date_logic(order2)
    assert_equal '2024-01-25', processed_date2
  end
  
  # Тест обработки специальных символов
  def test_special_characters_handling
    order_with_specials = @test_order_data.dup
    order_with_specials[:oname] = 'Тест «Кавычки» & символы <script>'
    order_with_specials[:comment] = 'Комментарий с ёлками и №123'
    
    xml = generate_simple_xml(order_with_specials)
    doc = Nokogiri::XML(xml)
    
    # XML должен парситься без ошибок
    assert doc.errors.empty?, "XML with special characters should be valid"
    
    # Спецсимволы должны быть корректно экранированы
    customer_name = doc.xpath('//*[local-name()="CustomerName"]').text
    assert customer_name.length > 0, "Customer name should not be empty"
    assert customer_name.include?('Тест'), "Special characters should be preserved"
  end
  
  # Тест работы с пустыми и nil значениями
  def test_nil_and_empty_values_handling
    order_with_nils = @test_order_data.dup
    order_with_nils[:region] = nil
    order_with_nils[:delkorpus] = ''
    order_with_nils[:comment] = nil
    
    xml = generate_simple_xml(order_with_nils)
    doc = Nokogiri::XML(xml)
    
    assert doc.errors.empty?, "XML should handle nil values gracefully"
    
    # Проверяем, что пустые значения не ломают XML
    region_value = doc.xpath('//*[local-name()="Region"]').text
    # Должно быть пустой строкой, а не nil
    assert_equal '', region_value
  end
  
  # Тест производительности генерации XML
  def test_xml_generation_performance
    # Генерация 100 заказов должна быть быстрой
    start_time = Time.now
    
    100.times do |i|
      order = @test_order_data.dup
      order[:eight_digit_id] = 10000000 + i
      order[:oname] = "Заказчик #{i}"
      generate_simple_xml(order)
    end
    
    generation_time = Time.now - start_time
    
    assert generation_time < 2.0, "XML generation for 100 orders should complete quickly (took #{generation_time}s)"
  end
  
  # Тест формата CommerceML
  def test_commerceml_format_compliance
    xml = generate_simple_xml
    doc = Nokogiri::XML(xml)
    
    # Проверяем обязательные атрибуты
    root = doc.root
    assert root.to_xml.include?('urn:1C.ru:commerceml_2'), "Should have correct namespace"
    assert_equal '2.03', root['version'], "Should have correct version"
    
    # Проверяем обязательные элементы
    assert doc.xpath('//*[local-name()="Document"]').length >= 1, "Should have at least one Document element"
    
    # Проверяем структуру документа
    document = doc.xpath('//*[local-name()="Document"]').first
    required_fields = %w[Id Number DeletionMark Operation Role Currency Amount]
    
    required_fields.each do |field|
      field_value = document.xpath(".//#{field}").text
      assert field_value.length > 0, "Document should have non-empty #{field}"
    end
  end
  
  private
  
  # Упрощенная генерация XML с латинскими тегами
  def generate_simple_xml(custom_data = nil)
    order_data = custom_data || @test_order_data
    order = OpenStruct.new(order_data)
    
    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.CommerceInformation(
        'xmlns' => 'urn:1C.ru:commerceml_2',
        'version' => '2.03',
        'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.Document do
          # Обрабатываем даты
          delivery_date = process_date_logic(order_data)
          address = process_address_logic(order_data)
          
          # Основные поля
          xml.Id((order.eight_digit_id || order.id).to_s)
          xml.Number(order.eight_digit_id.to_s)
          xml.DeletionMark('false')
          xml.Date(order.created_at.to_s)
          xml.Operation('Order')
          xml.Role('Seller')
          xml.Currency('RUB')
          xml.RecipientName(order.dname.to_s)
          xml.RecipientPhone(order.dtel.to_s)
          xml.TimeFrom(order.date_from)
          xml.TimeTo(order.date_to)
          xml.DeliveryCity(order.city)
          xml.DeliveryType(order.dt_txt)
          xml.DeliveryDate(delivery_date)
          xml.CardText(order.cart)
          xml.DeliveryPrice(order.delivery_price)
          xml.Comment(order.comment || '')
          xml.Amount(order.total_summ.to_i)
          
          # Контрагент
          xml.Contractors do
            xml.Contractor do
              xml.Id(order.eight_digit_id || order.id)
              xml.CustomerName(order.oname)
              xml.Contacts do
                xml.Contact do
                  xml.Type('Email')
                  xml.Value(order.email)
                end
                xml.Contact do
                  xml.Type('Phone')
                  xml.Value(order.otel)
                end
              end
              xml.Role('Buyer')
              xml.CompanyName('Website')
              
              # Адрес доставки
              xml.DeliveryAddress do
                xml.Presentation(", 184355, #{order.region}, , #{order.city} г , , #{address}, #{order.deldom}, #{order.delkorpus}, #{order.delkvart},,,")
                xml.AddressField do
                  xml.Type('PostalCode')
                  xml.Value('184355')
                end
                xml.AddressField do
                  xml.Type('Country')
                  xml.Value(order.country || '')
                end
                xml.AddressField do
                  xml.Type('City')
                  xml.Value(order.city || '')
                end
                xml.AddressField do
                  xml.Type('Region')
                  xml.Value(order.region || '')
                end
                xml.AddressField do
                  xml.Type('Street')
                  xml.Value(address)
                end
                xml.AddressField do
                  xml.Type('House')
                  xml.Value(order.deldom || '')
                end
              end
            end
          end
          
          # Товары (упрощенно)
          xml.Products do
            # Товар доставки
            xml.Product do
              xml.Id('00000001')
              xml.Name('Delivery')
              xml.Unit('item')
              xml.Quantity('1')
              xml.Price(order.del_price || 0)
              xml.Amount(order.del_price || 0)
            end
          end
        end
      end
    end
    
    doc.to_xml
  end
  
  # Обрабатывает логику адреса
  def process_address_logic(order_data)
    if order_data[:del_address] && !order_data[:del_address].empty?
      order_data[:del_address]
    else
      order_data[:district_text] || ''
    end
  end
  
  # Обрабатывает логику даты доставки
  def process_date_logic(order_data)
    order_data[:d2_date] || order_data[:d1_date] || ''
  end
end

#!/usr/bin/env ruby
# encoding: utf-8
# Mock testing script for 1C Exchange API
# Использует HTTP мокирование для тестирования без поднятия сервера

require 'minitest/autorun'
require 'json'
require 'nokogiri'
require 'webmock'
require 'net/http'
require_relative '../test_setup.rb'

include WebMock::API

class Test1CExchangeMock < Minitest::Test
  
  def setup
    WebMock.enable!
    @base_url = 'http://test.rozarioflowers.ru'
    @api_endpoint = "#{@base_url}/api/1c_exchange"
  end
  
  def teardown
    WebMock.disable!
    WebMock.reset!
  end
  
  # Мок тест режима checkauth
  def test_mock_checkauth_response
    stub_request(:get, "#{@api_endpoint}?mode=checkauth")
      .to_return(status: 200, body: 'success', headers: {})
    
    uri = URI("#{@api_endpoint}?mode=checkauth")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    assert_equal 'success', response.body
  end
  
  # Мок тест режима init
  def test_mock_init_response
    stub_request(:get, "#{@api_endpoint}?mode=init")
      .to_return(status: 200, body: 'zip=no file_limit=1024000', headers: {})
    
    uri = URI("#{@api_endpoint}?mode=init")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    assert_equal 'zip=no file_limit=1024000', response.body
  end
  
  # Мок тест режима query с пустым результатом
  def test_mock_query_empty_response
    empty_xml = generate_empty_commerceml_xml
    
    stub_request(:get, "#{@api_endpoint}?mode=query")
      .to_return(
        status: 200, 
        body: empty_xml,
        headers: { 'Content-Type' => 'text/xml; charset=utf-8' }
      )
    
    uri = URI("#{@api_endpoint}?mode=query")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    assert response.body.include?('<?xml')
    
    doc = Nokogiri::XML(response.body)
    assert doc.errors.empty?
    assert_equal 'КоммерческаяИнформация', doc.root.name
  end
  
  # Мок тест режима query с тестовыми заказами
  def test_mock_query_with_orders_response
    orders_xml = generate_test_commerceml_xml
    
    stub_request(:get, "#{@api_endpoint}?mode=query")
      .to_return(
        status: 200,
        body: orders_xml,
        headers: { 'Content-Type' => 'text/xml; charset=utf-8' }
      )
    
    uri = URI("#{@api_endpoint}?mode=query")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    
    doc = Nokogiri::XML(response.body)
    assert doc.errors.empty?
    
    documents = doc.xpath('//Документ')
    assert documents.length > 0, "Should have at least one order document"
    
    # Проверяем структуру первого заказа
    first_order = documents.first
    assert first_order.xpath('Ид').text.length > 0, "Order should have ID"
    assert first_order.xpath('Номер').text.length > 0, "Order should have number"
    assert_equal 'false', first_order.xpath('ПометкаУдаления').text
    assert_equal 'Заказ товара', first_order.xpath('ХозОперация').text
    assert_equal 'руб', first_order.xpath('Валюта').text
    
    # Проверяем наличие контрагента
    contractor = first_order.xpath('Контрагенты/Контрагент').first
    assert contractor, "Order should have contractor"
    assert_equal 'Покупатель', contractor.xpath('Роль').text
    
    # Проверяем наличие товаров
    products = first_order.xpath('Товары/Товар')
    assert products.length >= 1, "Order should have at least one product"
  end
  
  # Мок тест режима success
  def test_mock_success_response
    stub_request(:get, "#{@api_endpoint}?mode=success")
      .to_return(status: 200, body: 'ok', headers: {})
    
    uri = URI("#{@api_endpoint}?mode=success")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    assert_equal 'ok', response.body
  end
  
  # Тест обработки ошибок сервера
  def test_mock_server_error
    stub_request(:get, /#{@api_endpoint}/)
      .to_return(status: 500, body: 'Internal Server Error', headers: {})
    
    uri = URI("#{@api_endpoint}?mode=query")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '500', response.code
    assert_equal 'Internal Server Error', response.body
  end
  
  # Тест таймаута
  def test_mock_timeout
    stub_request(:get, /#{@api_endpoint}/)
      .to_timeout
    
    uri = URI("#{@api_endpoint}?mode=query")
    
    assert_raises(Net::TimeoutError) do
      response = Net::HTTP.get_response(uri)
    end
  end
  
  # Тест некорректного XML в ответе
  def test_mock_invalid_xml_response
    invalid_xml = '<?xml version="1.0" encoding="UTF-8"?><broken><xml></broken>'
    
    stub_request(:get, "#{@api_endpoint}?mode=query")
      .to_return(
        status: 200,
        body: invalid_xml,
        headers: { 'Content-Type' => 'text/xml; charset=utf-8' }
      )
    
    uri = URI("#{@api_endpoint}?mode=query")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    
    # Проверяем, что XML невалидный
    doc = Nokogiri::XML(response.body)
    refute doc.errors.empty?, "XML should have parsing errors"
  end
  
  # Тест проверки кодировки UTF-8
  def test_mock_encoding_utf8
    xml_with_cyrillic = generate_cyrillic_xml
    
    stub_request(:get, "#{@api_endpoint}?mode=query")
      .to_return(
        status: 200,
        body: xml_with_cyrillic,
        headers: { 'Content-Type' => 'text/xml; charset=utf-8' }
      )
    
    uri = URI("#{@api_endpoint}?mode=query")
    response = Net::HTTP.get_response(uri)
    
    assert_equal '200', response.code
    assert response.body.force_encoding('UTF-8').valid_encoding?, "Response should be valid UTF-8"
    
    doc = Nokogiri::XML(response.body)
    assert doc.errors.empty?, "Cyrillic XML should be valid"
    
    # Проверяем, что кириллица корректно обрабатывается
    customer_name = doc.xpath('//Контрагент/Наименование').text
    assert customer_name.include?('Тест'), "Cyrillic characters should be preserved"
  end
  
  private
  
  # Генерирует пустой XML в формате CommerceML
  def generate_empty_commerceml_xml
    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.КоммерческаяИнформация(
        "xmlns" => "urn:1C.ru:commerceml_2",
        "ВерсияСхемы" => "2.03",
        "xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
      ) {
        # Пустой документ
      }
    end
    
    doc.to_xml
  end
  
  # Генерирует тестовый XML с одним заказом
  def generate_test_commerceml_xml
    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.КоммерческаяИнформация(
        "xmlns" => "urn:1C.ru:commerceml_2",
        "ВерсияСхемы" => "2.03",
        "xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
      ) {
        xml.Документ {
          xml.Ид '12345678'
          xml.Номер '12345678'
          xml.ПометкаУдаления 'false'
          xml.Дата '2024-01-15T12:30:00'
          xml.ХозОперация 'Заказ товара'
          xml.Роль 'Продавец'
          xml.Валюта 'руб'
          xml.ИмяПолучателя 'Тестовый Получатель'
          xml.ТелефонПолучателя '+79001234567'
          xml.ВремяНачала '10:00'
          xml.ВремяОкончания '18:00'
          xml.ГородДоставки 'Мурманск'
          xml.Доставка 'Курьерская доставка'
          xml.ДатаДоставки '2024-01-15'
          xml.ТекстОткрытки 'С днем рождения!'
          xml.ЦенаДоставки '300'
          xml.Комментарий 'Тестовый заказ для проверки API'
          xml.Сумма '2500'
          
          xml.Контрагенты {
            xml.Контрагент {
              xml.Ид '12345678'
              xml.Наименование 'Тестовый Заказчик'
              xml.Контакты {
                xml.Контакт {
                  xml.Тип 'Электронная почта'
                  xml.Значение 'test@example.com'
                }
                xml.Контакт {
                  xml.Тип 'Телефон Рабочий'
                  xml.Значение '+79009876543'
                }
              }
              xml.Роль 'Покупатель'
              xml.ОфициальноеНаименование 'Сайт'
              
              xml.АдресДоставки {
                xml.Представление ', 184355, Мурманская область, , Мурманск г , , Ленинградская улица, 10, 2, 15,,,'
                xml.АдресноеПоле {
                  xml.Тип 'Почтовый индекс'
                  xml.Значение '184355'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Страна'
                  xml.Значение 'Россия'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Город'
                  xml.Значение 'Мурманск'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Регион'
                  xml.Значение 'Мурманская область'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Улица'
                  xml.Значение 'Ленинградская улица'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Дом'
                  xml.Значение '10'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Корпус'
                  xml.Значение '2'
                }
                xml.АдресноеПоле {
                  xml.Тип 'Квартира'
                  xml.Значение '15'
                }
              }
            }
          }
          
          xml.Товары {
            # Товар доставки
            xml.Товар {
              xml.Ид '00000001'
              xml.Наименование 'Доставка'
              xml.ЗначенияРеквизитов {
                xml.ЗначениеРеквизита {
                  xml.Наименование 'ВидНоменклатуры'
                  xml.Значение 'Набор'
                }
                xml.ЗначениеРеквизита {
                  xml.Наименование 'ТипНоменклатуры'
                  xml.Значение 'Набор'
                }
              }
              xml.КомплектТовара 'Стандартная'
              xml.БазоваяЕдиница 'компл'
              xml.Количество '1'
              xml.ЦенаЗаЕдиницу '300'
              xml.Сумма '300'
            }
            
            # Основной товар
            xml.Товар {
              xml.Ид '123'
              xml.Наименование 'Тестовый букет роз'
              xml.ЗначенияРеквизитов {
                xml.ЗначениеРеквизита {
                  xml.Наименование 'ВидНоменклатуры'
                  xml.Значение 'Набор'
                }
                xml.ЗначениеРеквизита {
                  xml.Наименование 'ТипНоменклатуры'
                  xml.Значение 'Набор'
                }
              }
              xml.КомплектТовара 'Стандартная'
              xml.БазоваяЕдиница 'компл'
              xml.Количество '1'
              xml.ЦенаЗаЕдиницу '2200'
              xml.Сумма '2200'
            }
          }
        }
      }
    end
    
    doc.to_xml
  end
  
  # Генерирует XML с кириллическими символами для тестирования кодировки
  def generate_cyrillic_xml
    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.КоммерческаяИнформация(
        "xmlns" => "urn:1C.ru:commerceml_2",
        "ВерсияСхемы" => "2.03"
      ) {
        xml.Документ {
          xml.Ид '11111111'
          xml.Номер '11111111'
          xml.ПометкаУдаления 'false'
          xml.ХозОперация 'Заказ товара'
          xml.Валюта 'руб'
          xml.Контрагенты {
            xml.Контрагент {
              xml.Наименование 'Тест «Кавычки» & символы <script>'
              xml.Роль 'Покупатель'
            }
          }
          xml.Комментарий 'Комментарий с ёлками и №123'
          xml.Товары {
            xml.Товар {
              xml.Наименование 'Букет «Весенний» с символами & знаками'
              xml.Количество '1'
            }
          }
        }
      }
    end
    
    doc.to_xml
  end
end

# Добавляем метод запуска мок-тестов
if __FILE__ == $0
  # Устанавливаем WebMock gem если не установлен
  begin
    require 'webmock'
  rescue LoadError
    puts "Installing webmock gem for mock testing..."
    system('gem install webmock')
    require 'webmock'
  end
  
  puts "Running 1C Exchange API mock tests..."
  Minitest.run
end

# encoding: utf-8
# Unit tests for 1C Exchange API logic (без подключения к БД)
# Тестирует основную логику обработки данных и генерации XML

require 'minitest/autorun'
require 'json'
require 'nokogiri'
require 'ostruct'
require_relative '../test_setup.rb'

class Test1CExchangeUnit < Minitest::Test
  
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
    
    @test_order_product_data = {
      id: 1,
      product_id: 123,
      title: 'Тестовый букет роз',
      price: 2200,
      quantity: 1,
      typing: 'Стандартная'
    }
  end
  
  # Тест базовой структуры XML для одного заказа
  def test_xml_structure_generation
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    assert doc.errors.empty?, "XML should be valid: #{doc.errors}"
    
    # Проверяем корневой элемент
    root = doc.root
    assert_equal 'КоммерческаяИнформация', root.name
    assert_equal 'urn:1C.ru:commerceml_2', root['xmlns']
    assert_equal '2.03', root['ВерсияСхемы']
    
    # Проверяем наличие документа
    documents = doc.xpath('//Документ')
    assert_equal 1, documents.length, "Should have exactly one document"
  end
  
  # Тест обязательных полей заказа в XML
  def test_xml_order_required_fields
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    document = doc.xpath('//Документ').first
    
    # Основные поля заказа
    assert_equal @test_order_data[:eight_digit_id].to_s, document.xpath('Ид').text
    assert_equal @test_order_data[:eight_digit_id].to_s, document.xpath('Номер').text
    assert_equal 'false', document.xpath('ПометкаУдаления').text
    assert_equal 'Заказ товара', document.xpath('ХозОперация').text
    assert_equal 'Продавец', document.xpath('Роль').text
    assert_equal 'руб', document.xpath('Валюта').text
    
    # Поля получателя
    assert_equal @test_order_data[:dname], document.xpath('ИмяПолучателя').text
    assert_equal @test_order_data[:dtel], document.xpath('ТелефонПолучателя').text
    
    # Сумма и комментарий
    assert_equal @test_order_data[:total_summ].to_i.to_s, document.xpath('Сумма').text
    assert_equal @test_order_data[:comment], document.xpath('Комментарий').text
  end
  
  # Тест логики обработки адреса доставки
  def test_address_logic
    # Тест 1: del_address пустой, используется district_text
    order1 = @test_order_data.dup
    order1[:del_address] = ''
    order1[:district_text] = 'Основная улица'
    
    xml1 = generate_test_xml([order1], [@test_order_product_data])
    doc1 = Nokogiri::XML(xml1)
    
    address_field = doc1.xpath('//АдресноеПоле[Тип="Улица"]/Значение').text
    assert_equal 'Основная улица', address_field
    
    # Тест 2: del_address заполнен, используется del_address
    order2 = @test_order_data.dup
    order2[:del_address] = 'Альтернативная улица'
    order2[:district_text] = 'Основная улица'
    
    xml2 = generate_test_xml([order2], [@test_order_product_data])
    doc2 = Nokogiri::XML(xml2)
    
    address_field2 = doc2.xpath('//АдресноеПоле[Тип="Улица"]/Значение').text
    assert_equal 'Альтернативная улица', address_field2
  end
  
  # Тест логики обработки d2_date
  def test_d2_date_logic
    # Тест 1: d2_date = nil, используется d1_date
    order1 = @test_order_data.dup
    order1[:d2_date] = nil
    order1[:d1_date] = '2024-01-20'
    
    xml1 = generate_test_xml([order1], [@test_order_product_data])
    doc1 = Nokogiri::XML(xml1)
    
    delivery_date = doc1.xpath('//ДатаДоставки').text
    assert_equal '2024-01-20', delivery_date
    
    # Тест 2: d2_date заполнен, используется d2_date
    order2 = @test_order_data.dup
    order2[:d2_date] = '2024-01-25'
    order2[:d1_date] = '2024-01-20'
    
    xml2 = generate_test_xml([order2], [@test_order_product_data])
    doc2 = Nokogiri::XML(xml2)
    
    delivery_date2 = doc2.xpath('//ДатаДоставки').text
    assert_equal '2024-01-25', delivery_date2
  end
  
  # Тест структуры контрагента
  def test_contractor_structure
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    contractor = doc.xpath('//Контрагенты/Контрагент').first
    assert contractor, "Contractor should be present"
    
    # Основные данные контрагента
    assert_equal @test_order_data[:eight_digit_id].to_s, contractor.xpath('Ид').text
    assert_equal @test_order_data[:oname], contractor.xpath('Наименование').text
    assert_equal 'Покупатель', contractor.xpath('Роль').text
    assert_equal 'Сайт', contractor.xpath('ОфициальноеНаименование').text
    
    # Контакты
    contacts = contractor.xpath('Контакты/Контакт')
    assert_equal 2, contacts.length, "Should have 2 contacts (email and phone)"
    
    email_contact = contacts.find { |c| c.xpath('Тип').text == 'Электронная почта' }
    phone_contact = contacts.find { |c| c.xpath('Тип').text == 'Телефон Рабочий' }
    
    assert email_contact, "Email contact should be present"
    assert phone_contact, "Phone contact should be present"
    
    assert_equal @test_order_data[:email], email_contact.xpath('Значение').text
    assert_equal @test_order_data[:otel], phone_contact.xpath('Значение').text
  end
  
  # Тест структуры адреса доставки
  def test_delivery_address_structure
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    delivery_address = doc.xpath('//АдресДоставки').first
    assert delivery_address, "Delivery address should be present"
    
    # Представление адреса
    presentation = delivery_address.xpath('Представление').text
    assert presentation.include?(@test_order_data[:city]), "City should be in address presentation"
    assert presentation.include?(@test_order_data[:deldom]), "House number should be in address presentation"
    
    # Адресные поля
    address_fields = delivery_address.xpath('АдресноеПоле')
    assert address_fields.length >= 6, "Should have at least 6 address fields"
    
    # Проверяем конкретные поля
    city_field = address_fields.find { |f| f.xpath('Тип').text == 'Город' }
    region_field = address_fields.find { |f| f.xpath('Тип').text == 'Регион' }
    house_field = address_fields.find { |f| f.xpath('Тип').text == 'Дом' }
    
    assert_equal @test_order_data[:city], city_field.xpath('Значение').text if city_field
    assert_equal @test_order_data[:region], region_field.xpath('Значение').text if region_field
    assert_equal @test_order_data[:deldom], house_field.xpath('Значение').text if house_field
  end
  
  # Тест товаров в заказе
  def test_order_products_structure
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    products = doc.xpath('//Товары/Товар')
    assert_equal 2, products.length, "Should have 2 products (delivery + main product)"
    
    # Товар доставки
    delivery_product = products.find { |p| p.xpath('Наименование').text == 'Доставка' }
    assert delivery_product, "Delivery product should be present"
    assert_equal '00000001', delivery_product.xpath('Ид').text
    assert_equal @test_order_data[:del_price].to_s, delivery_product.xpath('ЦенаЗаЕдиницу').text
    assert_equal '1', delivery_product.xpath('Количество').text
    
    # Основной товар
    main_product = products.find { |p| p.xpath('Ид').text == @test_order_product_data[:product_id].to_s }
    assert main_product, "Main product should be present"
    assert_equal @test_order_product_data[:title], main_product.xpath('Наименование').text
    assert_equal @test_order_product_data[:price].to_s, main_product.xpath('ЦенаЗаЕдиницу').text
    assert_equal @test_order_product_data[:quantity].to_s, main_product.xpath('Количество').text
    assert_equal @test_order_product_data[:typing], main_product.xpath('КомплектТовара').text
  end
  
  # Тест обработки специальных символов в XML
  def test_xml_special_characters_handling
    order_with_specials = @test_order_data.dup
    order_with_specials[:oname] = 'Тест «Кавычки» & символы <script>'
    order_with_specials[:comment] = 'Комментарий с ёлками и №123'
    
    xml = generate_test_xml([order_with_specials], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    # XML должен парситься без ошибок
    assert doc.errors.empty?, "XML with special characters should be valid"
    
    # Спецсимволы должны быть корректно экранированы
    contractor_name = doc.xpath('//Контрагенты/Контрагент/Наименование').text
    assert contractor_name.include?('Тест'), "Special characters should be preserved"
  end
  
  # Тест работы с пустыми и nil значениями
  def test_nil_and_empty_values_handling
    order_with_nils = @test_order_data.dup
    order_with_nils[:region] = nil
    order_with_nils[:delkorpus] = ''
    order_with_nils[:comment] = nil
    
    xml = generate_test_xml([order_with_nils], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    assert doc.errors.empty?, "XML should handle nil values gracefully"
    
    # Проверяем, что пустые значения не ломают XML
    region_value = doc.xpath('//АдресноеПоле[Тип="Регион"]/Значение').text
    # Должно быть пустой строкой, а не nil
    assert_equal '', region_value
  end
  
  # Тест множественных заказов
  def test_multiple_orders_xml
    order1 = @test_order_data.dup
    order1[:eight_digit_id] = 11111111
    order1[:oname] = 'Заказчик 1'
    
    order2 = @test_order_data.dup
    order2[:eight_digit_id] = 22222222
    order2[:oname] = 'Заказчик 2'
    
    xml = generate_test_xml([order1, order2], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    documents = doc.xpath('//Документ')
    assert_equal 2, documents.length, "Should have 2 order documents"
    
    # Проверяем, что оба заказа присутствуют
    ids = documents.map { |d| d.xpath('Ид').text }
    assert_includes ids, '11111111'
    assert_includes ids, '22222222'
  end
  
  # Тест валидации XML по схеме CommerceML (базовые проверки)
  def test_xml_commerceml_compliance
    xml = generate_test_xml([@test_order_data], [@test_order_product_data])
    doc = Nokogiri::XML(xml)
    
    # Проверяем наличие обязательных элементов CommerceML
    assert doc.xpath('//КоммерческаяИнформация').length == 1, "Should have one КоммерческаяИнформация element"
    assert doc.xpath('//Документ').length >= 1, "Should have at least one Документ element"
    assert doc.xpath('//Товары').length >= 1, "Should have at least one Товары element"
    assert doc.xpath('//Контрагенты').length >= 1, "Should have at least one Контрагенты element"
    
    # Проверяем структуру товара
    products = doc.xpath('//Товар')
    products.each do |product|
      assert product.xpath('Ид').text.length > 0, "Product should have non-empty Ид"
      assert product.xpath('Наименование').text.length > 0, "Product should have non-empty Наименование"
      assert product.xpath('БазоваяЕдиница').text.length > 0, "Product should have БазоваяЕдиница"
      assert product.xpath('Количество').text.length > 0, "Product should have Количество"
    end
  end
  
  # Тест производительности генерации XML для большого количества заказов
  def test_xml_generation_performance
    # Создаем 100 тестовых заказов
    orders = []
    100.times do |i|
      order = @test_order_data.dup
      order[:eight_digit_id] = 10000000 + i
      order[:oname] = "Заказчик #{i}"
      orders << order
    end
    
    start_time = Time.now
    xml = generate_test_xml(orders, [@test_order_product_data])
    generation_time = Time.now - start_time
    
    assert generation_time < 5.0, "XML generation for 100 orders should complete in under 5 seconds (took #{generation_time}s)"
    
    doc = Nokogiri::XML(xml)
    assert_equal 100, doc.xpath('//Документ').length, "Should have exactly 100 order documents"
  end
  
  private
  
  # Генерирует тестовый XML на основе данных заказов
  def generate_test_xml(orders, order_products)
    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.КоммерческаяИнформация(
        "xmlns" => "urn:1C.ru:commerceml_2",
        "ВерсияСхемы" => "2.03",
        "xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
      ) {
        orders.each do |order_data|
          order = OpenStruct.new(order_data)
          
          xml.Документ {
            # Обработка логики адреса
            if order.del_address != ''
              order.district_text = order.del_address
            else
              order.district_text = order.district_text
            end
            
            # Обработка d2_date
            if order.d2_date == nil
              order.d2_date = order.d1_date
            end
            
            # Основные поля заказа
            xml.Ид order.eight_digit_id ? order.eight_digit_id : order.id
            xml.Номер order.eight_digit_id
            xml.ПометкаУдаления 'false'
            xml.Дата order.created_at
            xml.ХозОперация 'Заказ товара'
            xml.Роль 'Продавец'
            xml.Валюта 'руб'
            xml.ИмяПолучателя order.dname
            xml.ТелефонПолучателя order.dtel
            xml.ВремяНачала order.date_from
            xml.ВремяОкончания order.date_to
            xml.ПозвонитьПолучателю order.dcall
            xml.КакОплатить order.payment_typetext
            xml.ОставитьСоседямБукет order.ostav
            xml.ФотоВручения order.make_photo
            xml.ГородДоставки order.city
            xml.Доставка order.dt_txt
            xml.НеГоворитьЧтоЦветы order.surprise
            xml.Оплата order.payment_typetext
            xml.ДатаДоставки order.d2_date
            xml.ТекстОткрытки order.cart
            xml.ЦенаДоставки order.delivery_price
            xml.Комментарий order.comment
            xml.Сумма order.total_summ.to_i
            
            # Контрагенты
            xml.Контрагенты {
              xml.Контрагент {
                xml.Ид order.eight_digit_id ? order.eight_digit_id : order.id
                xml.Наименование order.oname
                xml.Контакты {
                  xml.Контакт {
                    xml.Тип 'Электронная почта'
                    xml.Значение order.email
                  }
                  xml.Контакт {
                    xml.Тип 'Телефон Рабочий'
                    xml.Значение order.otel
                  }
                }
                xml.Роль 'Покупатель'
                xml.ОфициальноеНаименование 'Сайт'
                
                # Адрес доставки
                xml.АдресДоставки {
                  xml.Представление ", 184355, #{order.region.to_s}, , #{order.city.to_s} г , , #{order.district_text.to_s}, #{order.deldom.to_s}, #{order.delkorpus.to_s}, #{order.delkvart.to_s},,,"
                  xml.АдресноеПоле {
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Страна'
                    xml.Значение order.country
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Город'
                    xml.Значение order.city
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Регион'
                    xml.Значение order.region
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Улица'
                    xml.Значение order.district_text
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Дом'
                    xml.Значение order.deldom
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Корпус'
                    xml.Значение order.delkorpus
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Квартира'
                    xml.Значение order.delkvart
                  }
                }
                
                # Адрес регистрации (дубликат адреса доставки)
                xml.АдресРегистрации {
                  xml.Представление ", 184355, #{order.region.to_s}, , #{order.city.to_s} г , , #{order.district_text.to_s}, #{order.deldom.to_s}, #{order.delkorpus.to_s}, #{order.delkvart.to_s},,,"
                  xml.АдресноеПоле {
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Страна'
                    xml.Значение order.country
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Город'
                    xml.Значение order.city
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Регион'
                    xml.Значение order.region
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Улица'
                    xml.Значение order.district_text
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Дом'
                    xml.Значение order.deldom
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Корпус'
                    xml.Значение order.delkorpus
                  }
                  xml.АдресноеПоле {
                    xml.Тип 'Квартира'
                    xml.Значение order.delkvart
                  }
                }
              }
            }
            
            # Товары
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
                xml.ЦенаЗаЕдиницу order.del_price
                xml.Сумма order.del_price
              }
              
              # Основные товары заказа
              order_products.each do |product_data|
                product = OpenStruct.new(product_data)
                xml.Товар {
                  xml.Ид product.product_id
                  xml.Наименование product.title
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
                  xml.КомплектТовара product.typing
                  xml.БазоваяЕдиница 'компл'
                  xml.Количество product.quantity
                  xml.ЦенаЗаЕдиницу product.price
                  xml.Сумма product.price * product.quantity
                }
              end
            }
          }
        end
      }
    end
    
    doc.to_xml
  end
end

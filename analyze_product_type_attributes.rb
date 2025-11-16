#!/usr/bin/env ruby
# encoding: utf-8

# Анализ атрибутов типа продукта в Saleor
require 'net/http'
require 'json'
require 'uri'

class ProductTypeAnalyzer
  def initialize(endpoint, token)
    @endpoint = endpoint
    @token = token
  end

  def analyze_product_type_attributes
    puts "🔍 Анализируем атрибуты типов продуктов..."
    
    query = {
      query: """
        query {
          productTypes(first: 10) {
            edges {
              node {
                id
                name
                hasVariants
                variantAttributes {
                  id
                  name
                  slug
                  type
                  required
                  choices(first: 10) {
                    edges {
                      node {
                        id
                        name
                        slug
                      }
                    }
                  }
                }
                productAttributes {
                  id
                  name
                  slug
                  type
                  required
                }
              }
            }
          }
        }
      """
    }
    
    response = make_request(query)
    
    if response && response['data'] && response['data']['productTypes']
      product_types = response['data']['productTypes']['edges']
      
      product_types.each do |edge|
        product_type = edge['node']
        puts "\n📋 Тип продукта: #{product_type['name']} (ID: #{product_type['id']})"
        puts "   🔸 Поддерживает варианты: #{product_type['hasVariants']}"
        
        if product_type['hasVariants']
          puts "   🏷️  Атрибуты вариантов:"
          product_type['variantAttributes'].each do |attr|
            puts "     - #{attr['name']} (#{attr['slug']})"
            puts "       Тип: #{attr['type']}, Обязательный: #{attr['required']}"
            
            if attr['choices']['edges'].any?
              puts "       Варианты значений:"
              attr['choices']['edges'].each do |choice|
                puts "         * #{choice['node']['name']} (#{choice['node']['slug']})"
              end
            end
          end
        end
        
        puts "   📦 Атрибуты продукта:"
        product_type['productAttributes'].each do |attr|
          puts "     - #{attr['name']} (#{attr['slug']})"
          puts "       Тип: #{attr['type']}, Обязательный: #{attr['required']}"
        end
        
        puts "   " + "─" * 50
      end
      
      # Находим простейший тип для тестирования
      simple_types = product_types.select do |edge|
        pt = edge['node']
        pt['hasVariants'] && 
        pt['variantAttributes'].select { |a| a['required'] }.empty?
      end
      
      if simple_types.any?
        simple_type = simple_types.first['node']
        puts "\n✅ Найден простой тип для тестирования: #{simple_type['name']}"
        puts "   ID: #{simple_type['id']}"
        puts "   Обязательных атрибутов вариантов: 0"
        return simple_type
      else
        puts "\n⚠️  Все типы требуют обязательные атрибуты для вариантов"
        return product_types.first['node'] if product_types.any?
      end
    else
      puts "❌ Не удалось получить информацию о типах продуктов"
      return nil
    end
  end
  
  def create_simple_product_type
    puts "\n🛠️  Создаем простой тип продукта для Rozario..."
    
    mutation = {
      query: """
        mutation {
          productTypeCreate(input: {
            name: \"Rozario Flowers\"
            slug: \"rozario-flowers\"
            kind: NORMAL
            hasVariants: true
            isShippingRequired: true
            weight: 0.5
          }) {
            productType {
              id
              name
              slug
              hasVariants
            }
            errors {
              field
              message
              code
            }
          }
        }
      """
    }
    
    response = make_request(mutation)
    
    if response && response['data'] && response['data']['productTypeCreate']
      result = response['data']['productTypeCreate']
      if result['errors'] && result['errors'].any?
        puts "   ❌ Ошибка создания типа продукта:"
        result['errors'].each { |e| puts "     - #{e['message']}" }
        return nil
      elsif result['productType']
        pt = result['productType']
        puts "   ✅ Создан тип продукта: #{pt['name']} (#{pt['id']})"
        return pt
      end
    end
    
    puts "   ❌ Не удалось создать тип продукта"
    puts "   📋 Ответ сервера: #{response}" if response
    return nil
  end

  private

  def make_request(data)
    uri = URI(@endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = data.to_json
    
    begin
      response = http.request(request)
      JSON.parse(response.body)
    rescue => e
      puts "   ❌ Ошибка запроса: #{e.message}"
      nil
    end
  end
end

def main
  puts "🌿 Анализ типов продуктов Saleor для Rozario"
  puts "=" * 50
  
  endpoint = ENV['SALEOR_ENDPOINT']
  token = ENV['SALEOR_TOKEN']
  
  unless endpoint && token
    puts "❌ Необходимы переменные окружения: SALEOR_ENDPOINT и SALEOR_TOKEN"
    exit 1
  end
  
  analyzer = ProductTypeAnalyzer.new(endpoint, token)
  
  # Анализируем существующие типы
  suitable_type = analyzer.analyze_product_type_attributes
  
  if suitable_type.nil? || suitable_type['variantAttributes'].any? { |a| a['required'] }
    puts "\n🛠️  Существующие типы не подходят, создаем новый..."
    new_type = analyzer.create_simple_product_type
    
    if new_type
      puts "\n✅ Готов к использованию тип продукта: #{new_type['name']}"
      puts "   ID для экспортера: #{new_type['id']}"
    else
      puts "\n❌ Не удалось создать подходящий тип продукта"
    end
  else
    puts "\n✅ Можно использовать существующий тип: #{suitable_type['name']}"
    puts "   ID для экспортера: #{suitable_type['id']}"
  end
end

if __FILE__ == $0
  main
end

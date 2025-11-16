#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'json'
require 'uri'

endpoint = ENV['SALEOR_ENDPOINT']
token = ENV['SALEOR_TOKEN']

uri = URI(endpoint)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'

query = {
  query: """
    query {
      products(first: 50, sortBy: {field: CREATED_AT, direction: DESC}) {
        edges {
          node {
            id
            name
            slug
            productType {
              name
            }
            category {
              name
            }
            variants {
              id
              name
              pricing {
                price {
                  gross {
                    amount
                    currency
                  }
                }
              }
            }
          }
        }
      }
    }
  """
}

request.body = query.to_json

begin
  response = http.request(request)
  result = JSON.parse(response.body)
  
  puts "🔍 Проверка созданных продуктов Rozario:"
  puts "=" * 50
  
  if result['data'] && result['data']['products']
    products = result['data']['products']['edges']
    puts "📊 Найдено продуктов: #{products.length}"
  puts "🏷️  Фильтруем продукты Rozario Flowers..."
  
  rozario_products = products.select { |p| p['node']['productType'] && p['node']['productType']['name'] == 'Rozario Flowers' }
  puts "🌸 Найдено продуктов Rozario: #{rozario_products.length}"
  
  # Показываем только Rozario продукты
  products_to_show = rozario_products.any? ? rozario_products : products.last(3)
    
    products_to_show.each_with_index do |product_edge, index|
      product = product_edge['node']
      puts "\n#{index + 1}. 📦 #{product['name']}"
      puts "   🆔 ID: #{product['id']}"
      puts "   🔗 Slug: #{product['slug']}"
      puts "   📁 Категория: #{product['category'] ? product['category']['name'] : 'Без категории'}"
      puts "   🔸 Варианты: #{product['variants'].length}"
      
      product['variants'].each do |variant|
        price = variant['pricing'] && variant['pricing']['price'] && variant['pricing']['price']['gross'] ? 
                "#{variant['pricing']['price']['gross']['amount']} #{variant['pricing']['price']['gross']['currency']}" : 
                "Цена не установлена"
        puts "      • #{variant['name']} - #{price}"
      end
    end
  else
    puts "❌ Продукты не найдены или ошибка запроса"
    puts "📋 Ответ сервера:"
    puts JSON.pretty_generate(result)
  end
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

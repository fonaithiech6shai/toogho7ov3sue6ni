#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'json'
require 'uri'

endpoint = ENV['SALEOR_ENDPOINT']
token = ENV['SALEOR_TOKEN']

# ID последнего созданного продукта
product_id = "UHJvZHVjdDoxODM="

uri = URI(endpoint)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'

query = {
  query: """
    query {
      product(id: \"#{product_id}\") {
        id
        name
        variants {
          id
          name
          channelListings {
            channel {
              name
              currencyCode
            }
            price {
              amount
              currency
            }
            costPrice {
              amount
              currency
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
  
  puts "💰 Проверка цен по каналам для продукта:"
  puts "=" * 50
  
  if result['data'] && result['data']['product']
    product = result['data']['product']
    puts "📦 Продукт: #{product['name']} (#{product['id']})"
    
    product['variants'].each_with_index do |variant, index|
      puts "\n#{index + 1}. 🔸 Вариант: #{variant['name']} (#{variant['id']})"
      
      if variant['channelListings'].any?
        variant['channelListings'].each do |listing|
          channel = listing['channel']
          price = listing['price']
          cost_price = listing['costPrice']
          
          puts "   📺 Канал: #{channel['name']} (#{channel['currencyCode']})"
          puts "      💵 Цена: #{price ? "#{price['amount']} #{price['currency']}" : "Не установлена"}"
          puts "      🏷️  Себестоимость: #{cost_price ? "#{cost_price['amount']} #{cost_price['currency']}" : "Не установлена"}"
        end
      else
        puts "   ❌ Нет настроек каналов для этого варианта"
      end
    end
  else
    puts "❌ Продукт не найден или ошибка запроса"
    puts "📋 Ответ сервера:"
    puts JSON.pretty_generate(result) if result
  end
  
rescue => e
  puts "❌ Ошибка: #{e.message}"
end

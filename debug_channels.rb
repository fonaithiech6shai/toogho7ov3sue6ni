#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'json'
require 'uri'

class SaleorDebugger
  def initialize(endpoint, token)
    @endpoint = endpoint
    @token = token
  end

  def debug_channels
    puts "🔍 Отладка каналов Saleor..."
    
    query = {
      query: "query { channels { id name isActive slug currencyCode } }"
    }
    
    response = make_request(query)
    
    puts "📋 Ответ сервера:"
    puts JSON.pretty_generate(response) if response
    
    if response && response['data'] && response['data']['channels']
      channels = response['data']['channels']
      puts "\n📊 Найдено каналов: #{channels.length}"
      
      channels.each_with_index do |channel, index|
        puts "   #{index + 1}. #{channel['name']} (#{channel['id']}) - #{channel['isActive'] ? 'Активен' : 'Неактивен'}"
      end
      
      active_channel = channels.find { |c| c['isActive'] }
      if active_channel
        puts "\n✅ Активный канал: #{active_channel['name']} (#{active_channel['id']})"
        return active_channel
      else
        puts "\n❌ Активных каналов не найдено"
      end
    else
      puts "❌ Не удалось получить каналы"
    end
    
    nil
  end

  def test_product_channel_add(product_id, channel_id)
    puts "\n🧪 Тестируем добавление продукта в канал..."
    puts "   Продукт: #{product_id}"
    puts "   Канал: #{channel_id}"
    
    mutation = {
      query: """
        mutation AddProductToChannel($id: ID!, $input: ProductChannelListingUpdateInput!) {
          productChannelListingUpdate(id: $id, input: $input) {
            product {
              id
              name
            }
            errors {
              field
              message
              code
            }
          }
        }
      """,
      variables: {
        id: product_id,
        input: {
          updateChannels: [{
            channelId: channel_id,
            isPublished: true,
            publicationDate: Time.now.strftime('%Y-%m-%d'),
            visibleInListings: true,
            isAvailableForPurchase: true,
            availableForPurchaseDate: Time.now.strftime('%Y-%m-%d')
          }]
        }
      }
    }
    
    puts "\n📤 Отправляем мутацию:"
    puts JSON.pretty_generate(mutation)
    
    response = make_request(mutation)
    
    puts "\n📥 Ответ сервера:"
    puts JSON.pretty_generate(response) if response
    
    response
  end

  private
  
  def make_request(data)
    uri = URI(@endpoint)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = data.to_json
    
    begin
      response = http.request(request)
      JSON.parse(response.body)
    rescue => e
      puts "❌ Ошибка запроса: #{e.message}"
      nil
    end
  end
end

# Запуск
endpoint = ENV['SALEOR_ENDPOINT']
token = ENV['SALEOR_TOKEN']

unless endpoint && token
  puts "❌ Необходимы переменные окружения: SALEOR_ENDPOINT и SALEOR_TOKEN"
  exit 1
end

debugger = SaleorDebugger.new(endpoint, token)
channel = debugger.debug_channels

# Попробуем с последним созданным продуктом
if channel
  test_product_id = "UHJvZHVjdDoxODA=" # ID последнего созданного продукта
  debugger.test_product_channel_add(test_product_id, channel['id'])
end

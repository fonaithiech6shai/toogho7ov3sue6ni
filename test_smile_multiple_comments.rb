# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки отображения нескольких отзывов на странице smile

require 'bundler/setup'
require File.expand_path('../config/boot.rb', __FILE__)

class TestSmileMultipleComments
  def self.run
    puts "=== Тест отображения нескольких отзывов для объекта Smile ==="
    
    # Тест 1: Проверяем модель Smile
    test_smile_model
    
    # Тест 2: Проверяем связи комментариев
    test_comment_relations
    
    puts "\n=== Тест завершен ==="
  end
  
  private
  
  def self.test_smile_model
    puts "\n1. Тестируем методы модели Smile:"
    
    # Ищем smile с привязанным номером заказа
    smile_with_order = Smile.where("order_eight_digit_id IS NOT NULL").first
    
    if smile_with_order.nil?
      puts "⚠️  Не найдено ни одного объекта Smile с привязанным номером заказа"
      return
    end
    
    puts "   Найден Smile ID: #{smile_with_order.id}, заказ: #{smile_with_order.order_eight_digit_id}"
    
    # Тестируем новые методы
    related_comments = smile_with_order.related_comments
    puts "   Связанных комментариев: #{related_comments.size}"
    
    related_comments.each_with_index do |comment, index|
      puts "   Комментарий #{index + 1}: ID #{comment.id}, автор: '#{comment.name}', опубликован: #{comment.published?}"
    end
    
    # Тестируем методы совместимости
    puts "   has_review_comment?: #{smile_with_order.has_review_comment?}"
    puts "   has_review_comments?: #{smile_with_order.has_review_comments?}"
    
    first_comment = smile_with_order.related_comment
    puts "   related_comment (первый): #{first_comment ? first_comment.id : 'nil'}"
  end
  
  def self.test_comment_relations
    puts "\n2. Тестируем связи комментариев с заказами:"
    
    # Ищем заказы, у которых есть комментарии
    orders_with_comments = Order.joins("LEFT JOIN comments ON orders.eight_digit_id = comments.order_eight_digit_id")
                               .where("comments.id IS NOT NULL")
                               .group("orders.eight_digit_id")
                               .having("COUNT(comments.id) > 0")
                               .limit(5)
                               
    if orders_with_comments.empty?
      puts "⚠️  Не найдено заказов с комментариями"
      return
    end
    
    orders_with_comments.each do |order|
      comments_count = Comment.where(order_eight_digit_id: order.eight_digit_id).count
      smiles_count = Smile.where(order_eight_digit_id: order.eight_digit_id).count
      
      puts "   Заказ #{order.eight_digit_id}: комментариев #{comments_count}, смайлов #{smiles_count}"
      
      if smiles_count > 0
        smile = Smile.where(order_eight_digit_id: order.eight_digit_id).first
        puts "     → Smile ID #{smile.id} покажет #{smile.related_comments.size} отзывов"
      end
    end
  end
end

if __FILE__ == $0
  TestSmileMultipleComments.run
end

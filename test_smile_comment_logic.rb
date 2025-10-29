# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки логики получения связанных комментариев для улыбок

require_relative 'config/boot.rb'
require_relative 'app/helpers/common.rb'

class CommentLogicTest
  include CommonHelpers
  
  def run_tests
    puts "=== Тест логики получения связанных комментариев ==="
    
    # Тест 1: Проверим, есть ли улыбки с order_eight_digit_id
    smiles_with_orders = Smile.where.not(order_eight_digit_id: nil)
    puts "Найдено улыбок с order_eight_digit_id: #{smiles_with_orders.count}"
    
    if smiles_with_orders.any?
      smiles_with_orders.limit(5).each do |smile|
        puts "\nУлыбка ID: #{smile.id}, order_eight_digit_id: #{smile.order_eight_digit_id}"
        
        # Ищем комментарии по этому номеру заказа
        comments = Comment.where(order_eight_digit_id: smile.order_eight_digit_id)
        puts "  Найдено комментариев с таким же номером заказа: #{comments.count}"
        
        comments.each do |comment|
          published_status = bit_field_to_bool(comment.published)
          puts "    Комментарий ID: #{comment.id}, published: #{comment.published.inspect} (#{comment.published.class}), bool: #{published_status}"
          puts "    Имя: #{comment.name}, Тело: #{comment.body ? comment.body[0..50] + '...' : 'пусто'}"
        end
        
        # Проверим новый метод related_comment
        related = smile.related_comment
        puts "  Метод related_comment вернул: #{related ? related.id : 'nil'}"
        
        # Проверим has_review_comment?
        has_review = smile.has_review_comment?
        puts "  Метод has_review_comment? вернул: #{has_review}"
      end
    else
      puts "Улыбки с номерами заказов не найдены."
    end
    
    # Тест 2: Проверим, есть ли комментарии с order_eight_digit_id
    comments_with_orders = Comment.where.not(order_eight_digit_id: nil)
    puts "\nНайдено комментариев с order_eight_digit_id: #{comments_with_orders.count}"
    
    if comments_with_orders.any?
      comments_with_orders.limit(3).each do |comment|
        published_status = bit_field_to_bool(comment.published)
        puts "\nКомментарий ID: #{comment.id}, order_eight_digit_id: #{comment.order_eight_digit_id}"
        puts "  published: #{comment.published.inspect} (#{comment.published.class}), bool: #{published_status}"
        puts "  Имя: #{comment.name}"
        
        # Ищем улыбки с таким же номером заказа
        smiles = Smile.where(order_eight_digit_id: comment.order_eight_digit_id)
        puts "  Найдено улыбок с таким же номером заказа: #{smiles.count}"
      end
    end
    
    # Тест 3: Проверим scope published
    all_comments = Comment.count
    published_comments = Comment.published.count
    puts "\nВсего комментариев: #{all_comments}"
    puts "Опубликованных комментариев (через scope): #{published_comments}"
    
    # Тест 4: Проверим published вручную
    manual_published = Comment.all.select { |c| bit_field_to_bool(c.published) }.count
    puts "Опубликованных комментариев (вручную): #{manual_published}"
    
    puts "\n=== Тест завершен ==="
  end
end

test = CommentLogicTest.new
test.run_tests

#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки новой агрегированной Product + Reviews микроразметки

puts "=== Проверка агрегированной микроразметки ==="

show_template_content = File.read('app/views/smiles/show.erb')

# Проверяем новую Product схему
if show_template_content.include?('"@type": "Product"')
  puts "✅ Product схема найдена"
else
  puts "❌ Product схема не найдена!"
end

# Проверяем AggregateRating
if show_template_content.include?('"@type": "AggregateRating"')
  puts "✅ AggregateRating схема найдена"
else
  puts "❌ AggregateRating схема не найдена!"
end

# Проверяем массив отзывов
if show_template_content.include?('"review": [')
  puts "✅ Массив отзывов найден"
else
  puts "❌ Массив отзывов не найден!"
end

# Проверяем вычисление агрегированного рейтинга
if show_template_content.include?('total_rating += rating.to_f') && show_template_content.include?('average_rating =')
  puts "✅ Логика вычисления агрегированного рейтинга найдена"
else
  puts "❌ Логика вычисления агрегированного рейтинга не найдена!"
end

# Проверяем уникальные ID для каждого отзыва
if show_template_content.include?('#review-<%=@post.id%>-<%=index + 1%>')
  puts "✅ Уникальные ID для каждого отзыва найдены"
else
  puts "❌ Уникальные ID для каждого отзыва не найдены!"
end

# Проверяем корректность JSON структуры (запятые между отзывами)
if show_template_content.include?("index < @related_comments.size - 1 ? ',' : ''")
  puts "✅ Корректная JSON структура (запятые) найдена"
else
  puts "❌ Корректная JSON структура (запятые) не найдена!"
end

# Проверяем, что убрали старые отдельные Review схемы
individual_review_schemas = show_template_content.force_encoding('UTF-8').scan(/"@type": "Review".*?itemReviewed/).length
if individual_review_schemas == 0
  puts "✅ Отдельные Review схемы успешно убраны"
else
  puts "⚠️  Найдены #{individual_review_schemas} отдельные Review схемы (должно быть 0)"
end

puts "\n=== SEO преимущества новой схемы ==="
puts "✅ Агрегированный рейтинг в поисковой выдаче"
puts "✅ Показ количества отзывов"
puts "✅ Лучшая связка между Product и Reviews"
puts "✅ Оптимизация для Google Rich Snippets"

puts "\n=== Проверка завершена ==="

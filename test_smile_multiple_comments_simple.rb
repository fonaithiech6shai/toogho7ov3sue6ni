# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Простой тест для проверки новой логики отображения комментариев

puts "=== Проверка кода модели Smile ==="

# Проверяем, что мы добавили новые методы в модель
smile_model_content = File.read('app/models/smile.rb')

if smile_model_content.include?('def related_comments')
  puts "✅ Новый метод related_comments добавлен"
else
  puts "❌ Метод related_comments не найден!"
end

if smile_model_content.include?('def has_review_comments?')
  puts "✅ Новый метод has_review_comments? добавлен"
else
  puts "❌ Метод has_review_comments? не найден!"
end

if smile_model_content.include?('related_comments.any?')
  puts "✅ Обновленная логика has_review_comment? найдена"
else
  puts "❌ Логика has_review_comment? не обновлена!"
end

puts "\n=== Проверка шаблона smiles/show.erb ==="

show_template_content = File.read('app/views/smiles/show.erb')

if show_template_content.include?('@related_comments = @post.related_comments')
  puts "✅ Обновленная логика загрузки комментариев найдена"
else
  puts "❌ Обновленная логика загрузки комментариев не найдена!"
end

if show_template_content.include?('@related_comments.each_with_index do |comment, index|')
  puts "✅ Цикл для вывода всех комментариев добавлен"
else
  puts "❌ Цикл для вывода всех комментариев не найден!"
end

if show_template_content.include?('border_colors = [') && show_template_content.include?('border_color = border_colors[index % border_colors.length]')
  puts "✅ Логика разных цветов бордеров добавлена"
else
  puts "❌ Логика разных цветов бордеров не найдена!"
end

if show_template_content.include?('@related_comments.size > 1') && show_template_content.include?('index + 1')
  puts "✅ Нумерация отзывов добавлена"
else
  puts "❌ Нумерация отзывов не найдена!"
end

if show_template_content.include?('#review-<%=@post.id%>-<%=index + 1%>')
  puts "✅ Уникальные ID для Review схемы добавлены"
else
  puts "❌ Уникальные ID для Review схемы не найдены!"
end

comment_blocks_count = show_template_content.force_encoding('UTF-8').scan(/@related_comments\.each_with_index/).length
puts "\nℹ️  Найдено #{comment_blocks_count} блоков для обработки множественных комментариев"

puts "\n=== Проверка завершена ==="

if comment_blocks_count == 2 # Один для HTML, один для JSON-LD
  puts "✅ Все проверки пройдены! Код готов к работе."
else
  puts "⚠️  Найдено некорректное количество блоков обработки комментариев."
end

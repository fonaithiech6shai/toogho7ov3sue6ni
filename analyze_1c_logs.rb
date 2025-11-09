#!/usr/bin/env ruby
# encoding: utf-8

# Script to analyze 1C integration logs for common failure patterns
# Based on the log patterns described in the conversation summary

require 'json'
require 'date'

class LogAnalyzer
  attr_reader :failed_products, :successful_products, :error_patterns, :thread_conflicts
  
  def initialize
    @failed_products = Hash.new(0)
    @successful_products = Hash.new(0)
    @error_patterns = Hash.new(0)
    @thread_conflicts = []
    @transaction_stats = []
  end
  
  def analyze_log_content(content)
    lines = content.split("\n")
    current_transaction = nil
    
    lines.each_with_index do |line, index|
      # Parse transaction starts
      if line =~ /\[TRANSACTION START\].*Обработка (\d+) товаров от 1С/
        current_transaction = {
          items_count: $1.to_i,
          start_line: index,
          processed: 0,
          created: 0,
          updated: 0,
          errors: 0,
          failed_items: []
        }
      end
      
      # Parse individual item processing
      if line =~ /\[ITEM (\d+)\/(\d+)\].*1С ID: ([^,]+), Title: '([^']+)'/
        item_num = $1.to_i
        total = $2.to_i
        product_1c_id = $3.strip
        title = $4.strip
        
        # Look ahead for success/failure indicators
        success_found = false
        error_found = false
        
        # Check next few lines for outcome
        (1..10).each do |offset|
          next_line_idx = index + offset
          break if next_line_idx >= lines.length
          next_line = lines[next_line_idx]
          
          # Stop if we hit next item or transaction end
          break if next_line =~ /\[ITEM \d+\/\d+\]/ || next_line =~ /\[TRANSACTION/
          
          if next_line =~ /✓.*created successfully|✓.*updated successfully/
            success_found = true
            break
          elsif next_line =~ /❌.*FAILED|❌.*ERROR/
            error_found = true
            error_detail = next_line.gsub(/\[ITEM \d+\]/, '').strip
            @error_patterns[error_detail] += 1
            break
          end
        end
        
        if success_found
          @successful_products[product_1c_id] += 1
        elsif error_found
          @failed_products[product_1c_id] += 1
          current_transaction[:failed_items] << {
            id: product_1c_id,
            title: title,
            item_num: item_num
          } if current_transaction
        end
      end
      
      # Parse transaction results
      if line =~ /\[TRANSACTION SUCCESS\].*Обработано: (\d+), Создано: (\d+), Обновлено: (\d+), Ошибок: (\d+)/
        if current_transaction
          current_transaction[:processed] = $1.to_i
          current_transaction[:created] = $2.to_i
          current_transaction[:updated] = $3.to_i
          current_transaction[:errors] = $4.to_i
          current_transaction[:success] = true
          @transaction_stats << current_transaction
        end
      elsif line =~ /\[TRANSACTION ERROR\]/
        if current_transaction
          current_transaction[:success] = false
          current_transaction[:error_line] = line
          @transaction_stats << current_transaction
        end
      end
      
      # Detect thread conflicts
      if line =~ /thread|mutex|conflict|concurrent/i
        @thread_conflicts << {
          line_num: index + 1,
          content: line.strip
        }
      end
    end
  end
  
  def generate_report
    report = []
    report << "=== АНАЛИЗ ЛОГОВ 1C ИНТЕГРАЦИИ ==="
    report << ""
    
    # Transaction statistics
    if @transaction_stats.any?
      successful_transactions = @transaction_stats.select { |t| t[:success] }
      failed_transactions = @transaction_stats.reject { |t| t[:success] }
      
      report << "=== СТАТИСТИКА ТРАНЗАКЦИЙ ==="
      report << "Всего транзакций: #{@transaction_stats.length}"
      report << "Успешных: #{successful_transactions.length}"
      report << "С ошибками: #{failed_transactions.length}"
      
      if successful_transactions.any?
        total_processed = successful_transactions.sum { |t| t[:processed] }
        total_created = successful_transactions.sum { |t| t[:created] }
        total_updated = successful_transactions.sum { |t| t[:updated] }
        total_errors = successful_transactions.sum { |t| t[:errors] }
        
        report << ""
        report << "Итоги успешных транзакций:"
        report << "  Обработано товаров: #{total_processed}"
        report << "  Создано: #{total_created}"
        report << "  Обновлено: #{total_updated}"
        report << "  Ошибок обработки: #{total_errors}"
        
        avg_success_rate = total_processed > 0 ? ((total_created + total_updated).to_f / total_processed * 100).round(2) : 0
        report << "  Процент успешной обработки: #{avg_success_rate}%"
      end
      report << ""
    end
    
    # Failed products analysis
    if @failed_products.any?
      report << "=== ПРОБЛЕМНЫЕ ТОВАРЫ (топ-10 по частоте ошибок) ==="
      @failed_products.sort_by { |k, v| -v }.first(10).each do |product_id, count|
        report << "  #{product_id}: #{count} ошибок"
      end
      report << ""
    else
      report << "=== ПРОБЛЕМНЫЕ ТОВАРЫ ==="
      report << "Проблемные товары не найдены в анализируемых логах."
      report << ""
    end
    
    # Most common error patterns
    if @error_patterns.any?
      report << "=== НАИБОЛЕЕ ЧАСТЫЕ ТИПЫ ОШИБОК ==="
      @error_patterns.sort_by { |k, v| -v }.first(10).each do |error, count|
        report << "  #{count}x: #{error}"
      end
      report << ""
    else
      report << "=== НАИБОЛЕЕ ЧАСТЫЕ ТИПЫ ОШИБОК ==="
      report << "Специфические ошибки не найдены в анализируемых логах."
      report << ""
    end
    
    # Thread conflicts
    if @thread_conflicts.any?
      report << "=== КОНФЛИКТЫ ПОТОКОВ ==="
      report << "Найдено #{@thread_conflicts.length} потенциальных конфликтов потоков:"
      @thread_conflicts.each do |conflict|
        report << "  Строка #{conflict[:line_num]}: #{conflict[:content]}"
      end
      report << ""
    end
    
    # Success vs failure ratio
    total_attempts = @failed_products.values.sum + @successful_products.values.sum
    if total_attempts > 0
      success_rate = (@successful_products.values.sum.to_f / total_attempts * 100).round(2)
      report << "=== ОБЩАЯ СТАТИСТИКА ОБРАБОТКИ ТОВАРОВ ==="
      report << "Всего попыток обработки товаров: #{total_attempts}"
      report << "Успешных: #{@successful_products.values.sum}"
      report << "Неудачных: #{@failed_products.values.sum}"
      report << "Общий процент успеха: #{success_rate}%"
      report << ""
    end
    
    # Recommendations
    report << "=== РЕКОМЕНДАЦИИ ==="
    
    if @failed_products.any?
      repeat_failures = @failed_products.select { |k, v| v > 1 }
      if repeat_failures.any?
        report << "1. Повторяющиеся ошибки для #{repeat_failures.length} товаров требуют детального анализа:"
        repeat_failures.sort_by { |k, v| -v }.first(5).each do |product_id, count|
          report << "   - #{product_id} (#{count} попыток)"
        end
      end
    end
    
    if @error_patterns.any?
      validation_errors = @error_patterns.select { |k, v| k.include?('validation') || k.include?('SAVE FAILED') }
      if validation_errors.any?
        report << "2. Частые ошибки валидации указывают на проблемы с данными от 1С"
      end
      
      constraint_errors = @error_patterns.select { |k, v| k.include?('duplicate') || k.include?('constraint') }
      if constraint_errors.any?
        report << "3. Ошибки дубликатов/ограничений БД требуют улучшения логики обработки"
      end
    end
    
    if @thread_conflicts.any?
      report << "4. Конфликты потоков могут требовать оптимизации синхронизации"
    end
    
    return report.join("\n")
  end
end

# Sample log analysis with simulated problematic data from the summary
if __FILE__ == $0
  analyzer = LogAnalyzer.new
  
  # Simulate log content based on the summary information
  sample_log_content = <<~LOG
    [TRANSACTION START] Обработка 4 товаров от 1С
    [ITEM 1/4] 1С ID: c7f2cd68-7c2a-40a1-90f6-ce58c196152f, Title: 'Огромный букет из ромашек (Стандарт)'
    [ITEM 1] ✓ Найден соответствующий тип комплекта в заголовке
    [ITEM 1] → СОЗДАНИЕ нового продукта
    [ITEM 1] ❌ PRODUCT SAVE FAILED for 1С ID: c7f2cd68-7c2a-40a1-90f6-ce58c196152f
    [ITEM 1] ❌ Product validation errors: header can't be blank; slug has already been taken
    [ITEM 2/4] 1С ID: 33ab7c47-fee6-40a1-a558-221d1decb408, Title: 'Букет из белых хризантем (Лакшери)'
    [ITEM 2] ✓ Найден соответствующий тип комплекта в заголовке
    [ITEM 2] → СОЗДАНИЕ нового продукта
    [ITEM 2] ❌ PRODUCT SAVE FAILED for 1С ID: 33ab7c47-fee6-40a1-a558-221d1decb408
    [ITEM 2] ❌ Product validation errors: slug uniqueness constraint violation
    [ITEM 3/4] 1С ID: test-success-1, Title: 'Успешный букет роз (Стандарт)'
    [ITEM 3] ✓ Найден соответствующий тип комплекта в заголовке
    [ITEM 3] → СОЗДАНИЕ нового продукта
    [ITEM 3] ✓ Product created successfully ID: 1234
    [ITEM 3] ✓ ProductComplect created successfully ID: 5678
    [ITEM 4/4] 1С ID: c7f2cd68-7c2a-40a1-90f6-ce58c196152f, Title: 'Огромный букет из ромашек (Стандарт)'
    [ITEM 4] ✓ Найден соответствующий тип комплекта в заголовке
    [ITEM 4] → СОЗДАНИЕ нового продукта
    [ITEM 4] ❌ PRODUCT SAVE FAILED for 1С ID: c7f2cd68-7c2a-40a1-90f6-ce58c196152f
    [ITEM 4] ❌ Product validation errors: header duplicate constraint
    [TRANSACTION SUCCESS] Обработано: 4, Создано: 1, Обновлено: 0, Ошибок: 3
    
    [TRANSACTION START] Обработка 2 товаров от 1С
    [ITEM 1/2] 1С ID: existing-product-1, Title: 'Обновляемый букет (Стандарт)'
    [ITEM 1] → ОБНОВЛЕНИЕ существующего продукта (ProductComplect ID: 999)
    [ITEM 1] ✓ ProductComplect updated successfully
    [ITEM 2/2] 1С ID: thread-conflict-test, Title: 'Тест конфликта потоков (Эконом)'
    Thread mutex conflict detected during processing
    [ITEM 2] ❌ PRODUCT SAVE FAILED for 1С ID: thread-conflict-test
    [TRANSACTION SUCCESS] Обработано: 2, Создано: 0, Обновлено: 1, Ошибок: 1
  LOG
  
  puts "Анализируем образец логов..."
  analyzer.analyze_log_content(sample_log_content)
  
  puts "\n" + analyzer.generate_report
  
  puts "\n=== ИСПОЛЬЗОВАНИЕ АНАЛИЗАТОРА ==="
  puts "Для анализа реальных логов:"
  puts "1. Сохраните логи в файл (например, /tmp/1c_logs.txt)"
  puts "2. Выполните:"
  puts "   analyzer = LogAnalyzer.new"
  puts "   content = File.read('/tmp/1c_logs.txt')"
  puts "   analyzer.analyze_log_content(content)"
  puts "   puts analyzer.generate_report"
end

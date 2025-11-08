# encoding: utf-8
# Умная обработка кодировки - конвертирует только когда действительно нужно

# Устанавливаем UTF-8 как стандартную кодировку
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

if defined?(ActiveRecord)
  ActiveRecord::Base.class_eval do
    after_initialize :smart_utf8_encoding
    
    private
    
    def smart_utf8_encoding
      # Проходим по всем строковым атрибутам
      self.class.columns.each do |column|
        if column.type == :string || column.type == :text
          value = read_attribute(column.name)
          
          if value && value.respond_to?(:encoding) && value.respond_to?(:valid_encoding?)
            begin
              # КЛЮЧЕВОЕ ОТЛИЧИЕ: проверяем, нужна ли конвертация
              if needs_encoding_fix?(value)
                converted = fix_encoding(value)
                write_attribute(column.name, converted)
              end
            rescue => e
              # При любой ошибке оставляем значение без изменений
              # Лучше оставить как есть, чем испортить
            end
          end
        end
      end
    end
    
    # Определяет, нужна ли конвертация кодировки
    def needs_encoding_fix?(value)
      return false if value.nil? || value.empty?
      
      # Если строка уже в UTF-8 и валидна - НЕ трогаем
      if value.encoding == Encoding::UTF_8 && value.valid_encoding?
        return false
      end
      
      # Если кодировка ASCII-8BIT (байты) - возможно нужна конвертация
      if value.encoding == Encoding::ASCII_8BIT
        # Пробуем интерпретировать как UTF-8
        test_utf8 = value.dup.force_encoding(Encoding::UTF_8)
        if test_utf8.valid_encoding?
          # Если валидна как UTF-8, просто меняем кодировку без конвертации
          write_attribute(column.name, test_utf8)
          return false
        end
        # Если не валидна как UTF-8, возможно это Windows-1251
        return true
      end
      
      # Если в другой кодировке - возможно нужна конвертация
      return true
    end
    
    # Умная конвертация кодировки
    def fix_encoding(value)
      return value if value.nil? || value.empty?
      
      # Сначала пробуем простое изменение кодировки на UTF-8
      if value.encoding == Encoding::ASCII_8BIT
        test_utf8 = value.dup.force_encoding(Encoding::UTF_8)
        if test_utf8.valid_encoding?
          return test_utf8
        end
      end
      
      # Если не помогло, пробуем конвертацию из Windows-1251
      begin
        converted = value.dup.force_encoding('Windows-1251').encode('UTF-8')
        # Проверяем, что конвертация дала разумный результат
        if converted.valid_encoding? && !converted.empty?
          return converted
        end
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        # Windows-1251 не подошла
      end
      
      # Последняя попытка - принудительная очистка с заменой
      value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end
end

# Улучшенный хелпер для String
class String
  def smart_utf8
    return self if encoding == Encoding::UTF_8 && valid_encoding?
    
    # ASCII-8BIT - пробуем интерпретировать как UTF-8
    if encoding == Encoding::ASCII_8BIT
      test_utf8 = dup.force_encoding(Encoding::UTF_8)
      return test_utf8 if test_utf8.valid_encoding?
    end
    
    # Пробуем Windows-1251 -> UTF-8
    begin
      dup.force_encoding('Windows-1251').encode('UTF-8')
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      # Крайний случай - замена невалидных символов
      encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end
end
# encoding: utf-8
# Умная настройка MySQL кодировки без патчинга String
# ВАЖНО: Инициализируется только после установления соединения с БД

if defined?(ActiveRecord)
  # Настройка кодировки при соединении с MySQL
  module SmartMysqlEncoding
    def self.setup_connection(connection)
      return unless connection.class.name.include?('Mysql')
      
      begin
        # Пробуем utf8mb4 (поддерживает emoji и другие 4-байтовые символы)
        connection.execute("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci")
        connection.execute("SET CHARACTER SET utf8mb4")
      rescue => e
        begin
          # Fallback на обычный utf8
          connection.execute("SET NAMES utf8 COLLATE utf8_unicode_ci")
          connection.execute("SET CHARACTER SET utf8")
        rescue => inner_e
          # Если и это не сработало - просто продолжаем
          # Лучше работать с дефолтными настройками, чем сломать приложение
        end
      end
    end
    
    def self.apply_to_existing_connection
      # Проверяем, что соединение уже установлено
      if ActiveRecord::Base.connected?
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          setup_connection(conn)
        end
      end
    end
    
    def self.patch_new_connections
      # Настраиваем кодировку для новых соединений
      return unless ActiveRecord::Base.connected?
      
      # Используем более простой подход - патчим класс адаптера
      adapter_class = ActiveRecord::Base.connection.class
      
      unless adapter_class.instance_variable_get(:@smart_encoding_patched)
        adapter_class.class_eval do
          alias_method :original_new_connection, :new_connection if method_defined?(:new_connection)
          
          def new_connection(*args)
            conn = if respond_to?(:original_new_connection)
              original_new_connection(*args)
            else
              super(*args)
            end
            SmartMysqlEncoding.setup_connection(conn)
            conn
          end
        end
        
        adapter_class.instance_variable_set(:@smart_encoding_patched, true)
      end
    rescue => e
      # Если патчинг не удался - просто продолжаем
      puts "[WARNING] Could not patch connection adapter: #{e.message}" if ENV['DEBUG']
    end
  end
  
  # Простой и безопасный подход - настраиваем только текущее соединение
  # Новые соединения будут настроены при первом использовании
  # Это будет выполнено в config/apps.rb после монтирования
  # Не пытаемся патчить connection pool - это опасно
  
  # Просто настраиваем текущее соединение когда оно доступно
end

# encoding: utf-8
# Умная настройка MySQL кодировки без патчинга String

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
  end
  
  # Устанавливаем кодировку при соединении
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    SmartMysqlEncoding.setup_connection(conn)
  end
  
  # Настраиваем кодировку для новых соединений
  ActiveRecord::Base.connection_pool.instance_eval do
    def new_connection
      conn = super
      SmartMysqlEncoding.setup_connection(conn)
      conn
    end
  end
end
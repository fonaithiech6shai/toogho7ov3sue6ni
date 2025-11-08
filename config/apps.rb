# encoding: utf-8
require 'sidekiq'
require 'sidekiq/api'
require 'sidekiq/web'
require 'securerandom'

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/' + (ENV['RACK_ENV'].to_s === 'development' ? '0' : '0'), password: PADRINO_ENV == 'production' ? ENV['REDIS_PASSWORD'].to_s : 'foobared' }
end
Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/' + (ENV['RACK_ENV'].to_s === 'development' ? '0' : '0'), password: PADRINO_ENV == 'production' ? ENV['REDIS_PASSWORD'].to_s : 'foobared' }
end
# Sidekiq::Queue.new("default").clear # Очистить конкретную очередь
Sidekiq::Queue.new.clear        # Очистить все задачи в очереди
Sidekiq::RetrySet.new.clear     # Очистить очередь повторных задач
Sidekiq::ScheduledSet.new.clear # Очистить очередь запланированных задач
Sidekiq::Queue.new.each { |job| job.delete } # Удаление задачи
Sidekiq::Logging.logger = Logger.new('log/sidekiq.log')
Sidekiq.configure_server do |config|
  config.logger.level = Logger::INFO # Установить уровень логов для сервера
end
Sidekiq.configure_client do |config|
  config.logger.level = Logger::INFO # Установить уровень логов для клиента
end
# Logger::DEBUG — детализированные сообщения для отладки. Logger::INFO — информационные сообщения. Logger::WARN — предупреждения. Logger::ERROR — сообщения об ошибках. Logger::FATAL — фатальные ошибки. Logger::UNKNOWN — сообщения неизвестного типа.

Padrino.configure_apps do
  enable :sessions
  set :session_secret, PADRINO_ENV == 'production' ? ENV['PADRINO_SESSION_SECRET'].to_s : SecureRandom.hex(64) # Use `bundle exec rake secret`
  set :protection, false
  set :protect_from_csrf, false
  set :allow_disabled_csrf, true
  # set :cache, Padrino::Cache::Store::Redis.new(::Redis.new(url: "redis://:#{ENV['REDIS_PASSWORD'].to_s}@localhost:6379/0"))
end

# Mounts the core application for this project
Padrino.mount('Rozario::App',   :app_file => Padrino.root('app/app.rb')).to('/')
Padrino.mount("Rozario::Admin", :app_file => File.expand_path('../../admin/app.rb', __FILE__)).to("/admin")

# Инициализация smart encoding после монтирования приложений
if defined?(SmartMysqlEncoding)
  begin
    # Только настраиваем текущее соединение, без патчинга
    SmartMysqlEncoding.apply_to_existing_connection
    puts "[DEBUG] Smart MySQL encoding суспешно применен" if ENV['DEBUG']
  rescue => e
    puts "[WARNING] Smart MySQL encoding не может быть применен: #{e.message}" if ENV['DEBUG']
  end
end


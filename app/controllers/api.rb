# encoding: utf-8
require 'pathname'
require 'net/http'
require 'uri'
require 'fileutils'
require 'json'
require 'mini_magick'

# Глобальные переменные для хранения ссылок на потоки
$thread_running = false
$thread_mutex = Mutex.new
$test_thread_running = false
$test_thread_mutex = Mutex.new

Rozario::App.controllers :api do

  before do
    response['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate'
    response['Pragma'] = 'no-cache'
    response['Expires'] = '0'
  end

  get :process_image_links do
    content_type :text
    result = []
    ProductComplect.all.each { |x|
      next if x.all_images.nil? || x.all_images.strip == '' || x.all_images == '[]' # Проверяем, что `all_images` не пустой и не nil
      result = processing_all_images(JSON.parse(x.all_images), x.id_1C, overwrite=false)
    }
    return result.join("\n")
  end

  # get "test" do
  #   content_type :json
  #   # product_complect = ProductComplect.find(id_1C: "feb2a6ea-b29c-11e8-8146-52540077d4fc")
  #   # product_complect = ProductComplect.find(product_id: 3071)
  #   product_complect = ProductComplect.where(id_1C: "feb2a6ea-b29c-11e8-8146-52540077d4fc").first
  #   return product_complect.to_json
  # end

  # get "duplicates_id" do
  #   content_type :json
  #   result = []
  #   products = Product.all
  #   duplicates = products
  #     .group_by(&:header)
  #     .select { |header, items| items.size > 1 }
  #     .values
  #     .flatten
  #     .map(&:id)
  #   result = duplicates
  #   # Product.all.each { |x|
  #   #   Product.all.each { |y|
  #   #     if x.header == y.header and x.id != y.id
  #   #       result.append(x.id)
  #   #       break
  #   #     end
  #   #   }
  #   # }
  #   # result = Product # Группируем записи по header и выбираем те, у которых count > 1
  #   #   .select(:id, :header)
  #   #   .group(:header)
  #   #   .having('COUNT(header) > 1')
  #   #   .pluck(:id)
  #   return result.to_json # Возвращаем результат в формате JSON
  # end

  # get "duplicates_names" do
  #   content_type :json
  #   result = []
  #   products = Product.all
  #   duplicates = products
  #     .group_by(&:header)
  #     .select { |header, items| items.size > 1 }
  #     .values
  #     .flatten
  #     .map(&:header) # .map(&:id)
  #   result = duplicates
  #   return result.to_json # Возвращаем результат в формате JSON
  # end

  get :test do
    content_type :text
    result = []
    # ProductComplect.all.each{|x|
    #   if !x.main_image.nil?
    #     if x.main_image.include?("--- []")
    #       a = nil
    #     else
    #       a = x.main_image.nil? ? nil : x.main_image.gsub(/\\u([0-9a-fA-F]{4})/) { |match| [$1.to_i(16)].pack('U') }#JSON.parse(%Q{"#{x.main_image}"})
    #     end
    #   else
    #     a = nil
    #   end
    #   if !x.all_images.nil?
    #     if x.all_images.include?("--- []")
    #       b = nil
    #     else
    #       b = x.all_images.nil? ? nil : x.all_images.gsub(/\\u([0-9a-fA-F]{4})/) { |match| [$1.to_i(16)].pack('U') }#JSON.parse(%Q{"#{x.all_images}"})
    #     end
    #   else
    #     b = nil
    #   end
    #   if !x.discounts.nil?
    #     if x.discounts.include?("--- []")
    #       c = nil
    #     else
    #       c = x.discounts
    #     end
    #   else
    #     c = nil
    #   end
    #   result.append([a, b, c])
    # }
    # return result.to_json

    # ProductComplect.all.each { |x|
    #   if x.discounts != nil
    #     if x.discounts.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    #   if x.main_image != nil
    #     if x.main_image.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    #   if x.all_images != nil
    #     if x.all_images.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    # }
    # return result.join("\n")

    # return "#{PADRINO_ROOT}"
  end

  helpers do
    def processing_all_images(all_images, id_1C, overwrite=true)
      result = []

      destination                 = "/srv/rozarioflowers.ru/public/product_images/#{id_1C}/"
      destination_webp            = "/srv/grunt/webp/product_images/#{id_1C}/"
      destination_webp_thumbnails = "/srv/grunt/webp/product_images_thumbnails/#{id_1C}/"

      [destination, destination_webp, destination_webp_thumbnails].each { |path| Pathname.new(path).mkpath } # Создаём нужные папки

      all_images.each { |img| # Обрабатываем каждое изображение из JSON
        begin
          uri = URI.parse(img['url']); path = uri.path # Разбираем URL на компоненты
          filename = File.basename(path)
          file_path = File.join(destination, filename)
          webp_filename = File.basename(filename, File.extname(filename)) + '.webp'
          webp_filepath = File.join(destination_webp, webp_filename)
          webp_thumbnail_filepath = File.join(destination_webp_thumbnails, webp_filename)

          if !File.exist?(file_path) || overwrite
            image_data = Net::HTTP.get_response(uri).body # Скачиваем изображение
            File.open(file_path, 'wb') { |f| f.write(image_data) } # Сохраняем изображение в папку назначения с сохранением имени файла
          end

          if !File.exist?(webp_filepath) || overwrite # Конвертипровать в WebP
            image = MiniMagick::Image.open(file_path)
            image.format 'webp'
            image.write(webp_filepath)
          end

          if !File.exist?(webp_thumbnail_filepath) || overwrite # Создать миниатюру (thumbnail)
            create_thumbnail(webp_filepath, webp_thumbnail_filepath, 300)
            result.append("Обработано изображение: #{filename}")
          end
        rescue => e
          result.append("Ошибка обработки изображения #{img['url']}: #{e.message}")
        end
      }
      return result
    end
    def create_thumbnail(source_path, destination_path, size) # Метод для создания миниатюры
      image = MiniMagick::Image.open(source_path)
      image.resize "#{size}x#{size}>"
      image.write(destination_path)
    end
    def recursive_http_request(http, request, attempts_number)
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess) || attempts_number == 1; return response 
      else
        sleep(1)
        return recursive_http_request(http, request, attempts_number - 1)
      end
    end
    def transliterate(text)
      transliteration_map = {
        'А' => 'A', 'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E', 'Ё' => 'E',
        'Ж' => 'Zh', 'З' => 'Z', 'И' => 'I', 'Й' => 'Y', 'К' => 'K', 'Л' => 'L', 'М' => 'M',
        'Н' => 'N', 'О' => 'O', 'П' => 'P', 'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U',
        'Ф' => 'F', 'Х' => 'Kh', 'Ц' => 'Ts', 'Ч' => 'Ch', 'Ш' => 'Sh', 'Щ' => 'Shch',
        'Ъ' => '', 'Ы' => 'Y', 'Ь' => '', 'Э' => 'E', 'Ю' => 'Yu', 'Я' => 'Ya',
        'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'e',
        'ж' => 'zh', 'з' => 'z', 'и' => 'i', 'й' => 'y', 'к' => 'k', 'л' => 'l', 'м' => 'm',
        'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u',
        'ф' => 'f', 'х' => 'kh', 'ц' => 'ts', 'ч' => 'ch', 'ш' => 'sh', 'щ' => 'shch',
        'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'yu', 'я' => 'ya'
      }
      text.chars.map { |char| transliteration_map[char] || char }.join
    end
    def to_slug(str)
      str = transliterate(str)
      return str.gsub(' ', '-').gsub(/[^\w-]/, '').downcase
    end
    def crud_product_complects_transaction(data, log)
      begin
        log.puts "[TRANSACTION START] Обработка #{data.length} товаров от 1С"
        processed_count = 0
        created_count = 0
        updated_count = 0
        error_count = 0
        
        ActiveRecord::Base.transaction do
          data.each_with_index { |x, index|
            str = x['title']
            product_1c_id = x['product_id']
            
            log.puts "[ITEM #{index + 1}/#{data.length}] 1С ID: #{product_1c_id}, Title: '#{str}'"
            
            # Получить все названия комплектов с кешированием
            @complects_cache ||= Complect.all.map(&:header)
            substrings = @complects_cache
            
            if substrings.any? { |substring| str.include?(substring) } # Если указанный в заголовке тип комплекта зарегистирован...
              log.puts "[ITEM #{index + 1}] ✓ Найден соответствующий тип комплекта в заголовке"
              
              product_complect = ProductComplect.where(id_1C: product_1c_id).first # Найти комплект по id_1C
              if product_complect.nil? # Если НЕ найден, то создать новый...
                log.puts "[ITEM #{index + 1}] → СОЗДАНИЕ нового продукта"
                
                # Извлечь тип комплекта из скобок
                bracket_matches = str.scan(/.*?\(([^)]+)\)/)
                if bracket_matches.empty?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Не удалось извлечь тип комплекта из скобок в '#{str}'"
                  error_count += 1
                  next
                end
                
                last_bracket_text = bracket_matches.last[0].strip
                log.puts "[ITEM #{index + 1}] Извлечен тип комплекта: '#{last_bracket_text}'"
                
                complect = Complect.where(header: last_bracket_text).first # Найти тип комплекта
                if complect.nil?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Тип комплекта '#{last_bracket_text}' не найден в БД"
                  log.puts "[ITEM #{index + 1}] Доступные типы комплектов: #{substrings.join(', ')}"
                  error_count += 1
                  next
                end
                
                log.puts "[ITEM #{index + 1}] ✓ Найден комплект ID #{complect.id}: '#{complect.header}'"
                
                # Обработка изображений
                if x['all_images'] && !x['all_images'].empty?
                  log.puts "[ITEM #{index + 1}] → Обработка #{x['all_images'].length rescue 'N/A'} изображений"
                  processing_all_images(x['all_images'], product_1c_id)
                end
                
                # Создание продукта
                product = Product.new
                product_header = x['title'].strip.gsub(/ *\([^)]+\)$/, '').strip
                product.header = product_header
                original_slug = to_slug(product_header)
                product.slug = original_slug
                product.rating = 5
                
                log.puts "[ITEM #{index + 1}] Создаем Product: header='#{product_header}', slug='#{original_slug}'"
                
                # Проверка на дубликаты slug'а
                existing_slug_count = Product.where(slug: original_slug).count
                if existing_slug_count > 0
                  log.puts "[ITEM #{index + 1}] ⚠️ WARNING: Найдено #{existing_slug_count} товаров с таким же slug '#{original_slug}'"
                  
                  # Генерируем уникальный slug
                  counter = 1
                  while Product.where(slug: product.slug).exists?
                    product.slug = "#{original_slug}-#{counter}"
                    counter += 1
                  end
                  log.puts "[ITEM #{index + 1}] → Скорректирован slug на '#{product.slug}'"
                end
                
                # Проверка на дубликаты header'а
                existing_header_count = Product.where(header: product_header).count
                if existing_header_count > 0
                  log.puts "[ITEM #{index + 1}] ⚠️ WARNING: Найдено #{existing_header_count} товаров с таким же заголовком '#{product_header}'"
                end
                
                if product.save
                    x['categories'].split(';').each { |category_name|
                      category = Category.where(title: category_name.strip).first
                      if category # Используются только существующие категории, в противном случае пропускаем...
                        bound = CategoriesProducts.new
                        bound.product_id = product.id
                        bound.category_id = category.id
                        bound.save
                      end
                    }
                    product_complect = ProductComplect.new
                    product_complect.product_id  = product.id
                    product_complect.complect_id = complect.id
                    product_complect.id_1C       = x['product_id']
                    product_complect.text        = x['text']
                    product_complect.size        = x['size']
                    product_complect.package     = x['package']
                    product_complect.components  = x['components']
                    product_complect.color       = x['color']
                    product_complect.categories  = x['categories']
                    product_complect.recipient   = x['recipient']
                    product_complect.reason      = x['reason']
                    product_complect.price       = x['price']
                    product_complect.price_1990  = x['price_1990']
                    product_complect.price_2890  = x['price_2890']
                    product_complect.price_3790  = x['price_3790']
                    product_complect.discounts   = x['discounts'].to_json
                    product_complect.main_image  = x['main_image'].to_json
                    product_complect.all_images  = x['all_images'].to_json
                    if !product_complect.save
                      log.puts "[ITEM #{index + 1}] ❌ PRODUCT_COMPLECT SAVE FAILED for 1С ID: #{product_1c_id}"
                      log.puts "[ITEM #{index + 1}] ❌ ProductComplect validation errors: #{product_complect.errors.full_messages.join('; ')}"
                      log.puts "[ITEM #{index + 1}] ❌ ProductComplect attributes:"
                      product_complect.attributes.each { |key, value| log.puts "[ITEM #{index + 1}]   #{key}: #{value.inspect}" if value }
                      error_count += 1
                      next
                    else
                      log.puts "[ITEM #{index + 1}] ✓ ProductComplect created successfully ID: #{product_complect.id}"
                      created_count += 1
                    end
                  else
                    log.puts "[ITEM #{index + 1}] ❌ PRODUCT SAVE FAILED for 1С ID: #{product_1c_id}"
                    log.puts "[ITEM #{index + 1}] ❌ Product validation errors: #{product.errors.full_messages.join('; ')}"
                    log.puts "[ITEM #{index + 1}] ❌ Product attributes:"
                    product.attributes.each { |key, value| log.puts "[ITEM #{index + 1}]   #{key}: #{value.inspect}" }
                    log.puts "[ITEM #{index + 1}] ❌ Database constraints check:"
                    log.puts "[ITEM #{index + 1}]   - Products with same header: #{Product.where(header: product_header).count}"
                    log.puts "[ITEM #{index + 1}]   - Products with same slug: #{Product.where(slug: product.slug).count}"
                    log.puts "[ITEM #{index + 1}]   - Encoding check: header is valid UTF-8: #{product_header.valid_encoding?}"
                    log.puts "[ITEM #{index + 1}]   - Encoding check: slug is valid UTF-8: #{product.slug.valid_encoding?}"
                    error_count += 1
                    next
                  end
              else # ...иначе обновить данные.
                log.puts "[ITEM #{index + 1}] → ОБНОВЛЕНИЕ существующего продукта (ProductComplect ID: #{product_complect.id})"
                product = Product.where(id: product_complect.product_id).first
                if product.nil?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Product не найден по ID #{product_complect.product_id} для ProductComplect ID #{product_complect.id}"
                  error_count += 1
                  next
                end
                
                log.puts "[ITEM #{index + 1}] ✓ Найден Product ID #{product.id}: '#{product.header}'"
                
                if product
                  x['categories'].split(';').each { |category_name|
                    category = Category.where(title: category_name.strip).first
                    if category
                      if CategoriesProducts.where(product_id: product.id, category_id: category.id).first.nil?
                        bound = CategoriesProducts.new
                        bound.product_id = product.id
                        bound.category_id = category.id
                        bound.save
                      end
                    end
                  }
                  old_header = product.header
                  product_name = x['title'].strip.gsub(/ *\([^)]+\)$/, '').strip
                  product.header = product_name
                  
                  if old_header != product_name
                    log.puts "[ITEM #{index + 1}] → Изменение заголовка: '#{old_header}' → '#{product_name}'"
                  end
                  product_complect.text       = x['text']
                  product_complect.size       = x['size']
                  product_complect.package    = x['package']
                  product_complect.components = x['components']
                  product_complect.color      = x['color']
                  product_complect.categories = x['categories']
                  product_complect.recipient  = x['recipient']
                  product_complect.reason     = x['reason']
                  product_complect.price      = x['price']
                  product_complect.price_1990 = x['price_1990']
                  product_complect.price_2890 = x['price_2890']
                  product_complect.price_3790 = x['price_3790']
                  product_complect.discounts  = x['discounts'].to_json
                  product_complect.main_image = x['main_image'].to_json
                  product_complect.all_images = x['all_images'].to_json
                  if !product_complect.save
                    log.puts "[ITEM #{index + 1}] ❌ UPDATE FAILED: ProductComplect не сохранен для 1С ID: #{product_1c_id}"
                    log.puts "[ITEM #{index + 1}] ❌ Update validation errors: #{product_complect.errors.full_messages.join('; ')}"
                    error_count += 1
                    next
                  else
                    log.puts "[ITEM #{index + 1}] ✓ ProductComplect updated successfully"
                    updated_count += 1
                  end
              end
              end
            else
              log.puts "[ITEM #{index + 1}] ⚠️ SKIPPED: Заголовок не содержит ни одного известного типа комплекта"
              log.puts "[ITEM #{index + 1}] Доступные типы: #{substrings.join(', ')}"
            end
            
            processed_count += 1
          }
        end
        log.puts "[TRANSACTION SUCCESS] Обработано: #{processed_count}, Создано: #{created_count}, Обновлено: #{updated_count}, Ошибок: #{error_count}"
        return true # Транзакция успешно завершена
      rescue ActiveRecord::RecordInvalid => e
        log.puts "[TRANSACTION ERROR] Ошибка валидации записи: #{e.message}"
        log.puts "[TRANSACTION ERROR] Record: #{e.record.class.name} #{e.record.inspect}"
        log.puts "[TRANSACTION ERROR] Validation errors: #{e.record.errors.full_messages.join('; ')}"
        log.puts "[TRANSACTION ERROR] Stacktrace (first 10 lines):"
        e.backtrace.first(10).each { |line| log.puts "[TRANSACTION ERROR]   #{line}" }
        return false # Ошибка валидации
      rescue StandardError => e
        log.puts "[TRANSACTION ERROR] Ошибка во время транзакции: #{e.class.name}: #{e.message}"
        log.puts "[TRANSACTION ERROR] Current processing stats - Processed: #{processed_count rescue 0}, Created: #{created_count rescue 0}, Updated: #{updated_count rescue 0}, Errors: #{error_count rescue 0}"
        log.puts "[TRANSACTION ERROR] Stacktrace (first 10 lines):"
        e.backtrace.first(10).each { |line| log.puts "[TRANSACTION ERROR]   #{line}" }
        return false  # Общая ошибка транзакции
      end
    end
  end

  get :all_id_1C do
    content_type :text
    result = []
    ProductComplect.all.each { |x|
      if x.id_1C != nil
        result.append("#{x.id},#{x.id_1C}")
      end
    }
    return result.join("\n")
  end

  get 'thread_list' do
    content_type :text
    result = []
    Thread.list.each { |t| result << t.inspect }
    return result.join("\n")
  end

  get 'mutex_test' do
    content_type :json
    if $test_thread_mutex.synchronize { $test_thread_running } # Проверяем, запущен ли поток
      status 409 # Конфликт
      return {message: "The process is already underway", status: "error"}.to_json
    end
    begin
      thread = Thread.new do
        begin
          $test_thread_mutex.synchronize { $test_thread_running = true }
          sleep 5
        ensure
          $test_thread_mutex.synchronize { $test_thread_running = false } # Освобождаем состояние потока после завершения
        end
      end
    rescue => e
      status 500 # Внутренняя ошибка сервера
      return {message: "An error occurred: #{e.message}", status: "error"}.to_json
    end
    return {message: "Operation completed successfully", status: "success"}.to_json
  end

  get '1c_notify_update' do # https://rozarioflowers.ru/api/1c_notify_update
    # curl -u bae15749-52e9-4420-b429-f9fb483f4e48:94036dbc-5bbc-4495-952c-9f2150047b9a -X GET https://rozarioflowers.ru/api/1c_notify_update
    # curl -X POST https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices -H "Content-Type: application/json" -d "{\"etag\": null, \"count\": 512}"
    # curl -X GET https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices/status
    content_type :json

    log_path = "#{PADRINO_ROOT}/log/1c_notify_update.log"

    if $thread_mutex.synchronize { $thread_running } # Проверить, запущен ли поток.
      File.open(log_path, 'a') do |log|
        log.puts "--> #{Time.now} - Конфликт при запуске потока. Поток уже запущен ранее..."
      end
      status 409 # Конфликт.
      return {message: "The process is already underway", status: "error"}.to_json
    end

    begin
      thread = Thread.new do # Создаем новый поток.
        begin
          $thread_mutex.synchronize { $thread_running = true } # Установить флаг потока как запущенный.
          File.open(log_path, 'a') do |log| # Открываем лог-файл для записи.
            
            ok = true # Praesumptio.

            # Записываем в лог начало процесса.
            log.puts "Начало процесса..." # Логируем время начала процесса.
            
            url = URI.parse('https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices') # Определить URL для POST запроса.
            
            # Создать объект запроса.
            http = Net::HTTP.new(url.host, url.port) # Создаем объект запроса.
            http.use_ssl = true
            request = Net::HTTP::Post.new(url.path, {'Content-Type' => 'application/json'}) # Создаем запрос.

            n = 512 / 4

            request.body = {'etag': nil, 'count': n}.to_json # Тело запроса в формате JSON.
            # response = http.request(request) # Отправляем запрос и получаем ответ.
            response = recursive_http_request(http, request, 7) # Отправить запрос с повтором при ошибке.
            response_code = response.code.to_i # Получить код ответа от сервера.

            if response_code == 200 # Если код ответа 200 (успешный)...
              response_data = JSON.parse(response.body) # Парсим JSON-ответ.
              etag       = response_data['etag']       # Извлечь etag из данных из ответа.
              updated_at = response_data['updated_at'] # Извлечь дату обновления из ответа.
              data       = response_data['data']       # Извлечь данные из ответа.
              pending    = response_data['pending'].to_i - data.length # Рассчитать оставшееся количество элементов (не удалось достучаться до разработчика 1С, чтобы реализовать это на стороне сервера).
              log.puts "Код ответа: #{response_code} | data.length: #{data.length} | etag: #{etag == '' || etag.nil? ? 'null' : etag} | updated_at: #{updated_at} | pending: #{pending}" # Логировать полученные данные
              if pending < 0; log.puts "ERROR_gf04s0FV"; end
              # n = pending if n > pending # Если запрашиваем данных больше, чем имеется в остатке, то скорректировать запрашиваемое число элементов.
              if data.length > 0
                begin
                  if !crud_product_complects_transaction(data, log) # Попытаться выполнить транзакцию с данными.
                    ok = false # Установить флаг ошибки.
                  end
                rescue => e
                  ok = false # Установить флаг ошибки.
                  log.puts "Произошла ошибка, транзакция откатана: #{e.message}" # Логировать ошибку.
                end
                if data.length <= n && pending > 0 # The length of the data array in the response matches the length specified in the query.
                  tail = pending % n # Вычислить остаток данных.
                  log.puts "Tail: #{tail}" # Логировать хвост.
                  n_requests = (pending - tail) / n # Рассчитать количество запросов для получения оставшихся данных.
                  n_requests = n_requests + 1 if tail > 0 # Если есть хвост, то добавить доп. запрос для него.
                  i = 1; failed = 0 # Инициализировать переменные для подсчета запросов и неудачных попыток.
                  log.puts "Ожидается запросов: #{n_requests}" # Логировать количество запросов.
                  while i <= n_requests && i > 0 && !etag.nil? # Если данных в ответе меньше или равно запрашиваемым, но есть остаток. Короче говоря, пока есть запросы, выполняем их...
                    log.puts "Запрос ##{i}" # Логировать номер запроса.
                    request = Net::HTTP::Post.new(url.path, {'Content-Type' => 'application/json'}) # Создать новый запрос.
                    n = i == n_requests ? tail : n # Если последний запрос, то запрашиваем ровно столько элементов, сколько осталось в хвосте.
                    request.body = {'etag': etag, 'count': n}.to_json # Установить тело запроса в формате JSON.
                    # response = http.request(request) # Отправляем запрос и получаем ответ.
                    response = recursive_http_request(http, request, 3) # Отправить запрос рекурсивно.
                    response_code = response.code.to_i # Получить код ответа.
                    if response_code == 200 # Если код ответа 200.
                      response_data = JSON.parse(response.body) # Парсить JSON-ответ.
                      data = response_data['data']             # Извлечь данные.
                      etag = response_data['etag']             # Извлечь etag.
                      updated_at = response_data['updated_at'] # Извлечь дату обновления.
                      pending    = response_data['pending'] - data.length # Рассчитать оставшееся количество данных.
                      log.puts "Код ответа: #{response_code} | data.length: #{data.length} | etag: #{etag == '' || etag.nil? ? 'null' : etag} | updated_at: #{updated_at} | pending: #{pending}" # Логировать информацию о полученных данных.
                      begin
                        crud_product_complects_transaction(data, log) # Попытаться выполнить транзакцию.
                        log.puts "Транзакция успешно завершена" # Логировать успешную транзакцию.
                        i += 1 # Увеличить счетчик запросов.
                      rescue => e
                        failed += 1 # Увеличить счетчик неудачных попыток.
                        if failed > 7 # Если количество неудачных попыток превышает 7, то...
                          ok = false # ...установить флаг ошибки и...
                          break # ...завершить цикл.
                        end
                        log.puts "Произошла ошибка, транзакция откатана: #{e.message}" # Логировать ошибку.
                      end
                    else
                      ok = false # Установить флаг ошибки.
                      log.puts "ERROR_d0j8hjoy. Соединение не удалось (2). Код ответа: #{response_code}" # Логировать ошибку соединения.
                    end
                  end
                elsif data.length <= n && pending == 0 # Если данных достаточно и остаток пуст, то...
                  log.puts "Повторных запросов непотребовалось" # ...логировать, что дополнительных запросов не потребовалось.
                elsif data.length > n # Если данных больше, чем требуется, то...
                  ok = false # ...установить флаг ошибки и...
                  log.puts "ERROR_j80oyhjd: Данных в ответе более, чем требовалось." # ...логировать ошибку.
                elsif data.length < n && pending != 0 # Если данных меньше, чем требуется, но есть остаток, то...
                  ok = false # ...установить флаг ошибки и...
                  log.puts "ERROR_b5766b79: Данных в ответе меньше, чем требовалось, имеется остаток." # ...логировать ошибку.
                end
              else
                log.puts "Данных для обработки не поступило."
              end
            else
              ok = false # Установить флаг ошибки.
              log.puts "ERROR_66b79b57. Соединение не удалось (1). Код ответа: #{response_code}" # Логировать ошибку соединения.
            end
            if ok # Сadence...
              request = Net::HTTP::Post.new(url.path, {'Content-Type' => 'application/json'}) # Создать запрос.
              request.body = {'etag': etag, 'count': 0}.to_json # Установить тело запроса с ошибкой в формате JSON.
              response = recursive_http_request(http, request, 3) # Отправить запрос рекурсивно.
              response_code = response.code.to_i # Получить код ответа.
              if response_code == 200; log.puts "Сервер извещён о состоянии передачи (ok == true)" # Логировать извещение о ошибке.
              else;                    log.puts "Не удалось известить сервер о состоянии передачи (ok == true)"; end # Логировать ошибку при извещении.
            else
              request = Net::HTTP::Post.new(url.path, {'Content-Type' => 'application/json'}) # Создать запрос.
              request.body = {'error': true }.to_json # Установить тело запроса с ошибкой в формате JSON.
              response = recursive_http_request(http, request, 3) # Отправить запрос рекурсивно.
              response_code = response.code.to_i # Получить код ответа.
              if response_code == 200; log.puts "Сервер извещён о состоянии передачи (ok == false)" # Логировать извещение о ошибке.
              else;                    log.puts "Не удалось известить сервер о состоянии передачи (ok == true)"; end # Логировать ошибку при извещении.
            end
            log.puts "Конец." # Логировать завершение процесса.
          end
        rescue => e
          File.open(log_path, 'a') do |log|
            log.puts "--> Общая ошибка при выполнении потока."
          end
        ensure
          sleep 5 # Небольшой таймаут во избежание коллизий 🍒
          $thread_mutex.synchronize { $thread_running = false } # Освободить состояние потока после завершения.
        end
      end
    rescue => e
      File.open(log_path, 'a') do |log|
        log.puts "--> #{Time.now} - Общая ошибка при выполнении потока."
      end
      status 500 # Внутренняя ошибка сервера
      return {message: "An error occurred: #{e.message}", status: "error"}.to_json # Вернуть сообщение об ошибке.
    end
    File.open(log_path, 'a') do |log|
      log.puts "--> #{Time.now} - Запущен поток."
    end
    return {message: "Operation completed successfully", status: "success"}.to_json # Вернуть сообщение об успешном начале операции.
  end

  get 'subdomain' do
    content_type :json
    return Subdomain.find_by_url(params['url']).to_json(include: :disabled_dates) if params['url'].present?
    return Subdomain.find_by_id(params['id']).to_json(include: :disabled_dates) if params['id'].present?
    return 401
  end

  post 'newbukety.json' do
    # puts "post 'newbukety.json'"
    jsonr = JSON.parse(request.body.read)
    limit = 4
    page = jsonr['page'] || 0
    @category = Category.find(55)
    categories =
      if jsonr['categories'].blank? || jsonr['categories'].empty?
        Category.where(parent_id: @category.id).select('id').map(&:id)
      else
        jsonr['categories']
      end
    min_price = jsonr['min_price'].blank? ? 0 : jsonr['min_price']
    max_price = jsonr['max_price'].blank? ? 1_000_000 : jsonr['max_price']
    joins = 'INNER JOIN categories_products ON products.id = categories_products.product_id'
    joins += ' INNER JOIN product_complects ON products.id = product_complects.product_id'
    whereprice = 'price >= ? AND price <= ?'
    products =
      if jsonr['tags'].blank? || jsonr['tags'].empty?
        Product.joins(joins).where('categories_products.category_id' => categories).where(whereprice, min_price, max_price)
      else
        Product.joins(joins + ' INNER JOIN products_tags ON products.id = products_tags.product_id').where('categories_products.category_id' => categories).where('products_tags.tag_id' => jsonr['tags']).where(whereprice, min_price, max_price)
      end
    @items = products.order(:orderp).uniq
    unless jsonr['sort_by'].blank?
      @items =
        if jsonr['sort_by'] == 'price-desc'
          @items.sort_by(&:price).reverse
        elsif jsonr['sort_by'] == 'price-asc'
          @items.sort_by(&:price)
        else
          @items.sort_by(&:title)
        end
    end
    @items = @items.drop(limit * page).take(limit)
    render 'category/withfilters', layout: false
  end

  get ('/testing') do
    regions = Subdomain.pluck(:subdomain_pool_id).uniq
    return regions.to_json
    a = []
    for reg in regions
      cities = Subdomain.where(subdomain_pool_id: reg).pluck(:url)
      h = Hash.new{|hsh,key| hsh[key] = [] }
      h[reg].push cities
      a.push(h)
    end
    return a.to_json
  end

  post 'category.json' do
    # puts "post category.json do api.rb"
    js = JSON.parse(request.body.read)
    p ["API PARAMS", js]
    content_type :json
    categories = Category.where(:parent_id => js["id"]).select("id").map {|c| c.id}
    joins = "INNER JOIN categories_products ON products.id = categories_products.product_id"
    price = [0, 10000000]
    price = js["price"] if not js["price"].blank?
    if js["tags"].blank?
      products = Product.joins(joins).where('categories_products.category_id' => categories).where("price >= ? AND price <= ?", price[0], price[1])
    else
      joins += " INNER JOIN products_tags ON products.id = products_tags.product_id"
      products = Product.joins(joins).where('categories_products.category_id' => categories).where("price >= ? AND price <= ?", price[0], price[1]).where('products_tags.tag_id' => js["tags"])
    end
    products.uniq.to_json
  end

  get 'cities2.json' do
    # puts "get 'cities2.json' do api.rb"
    content_type :json
    cities2 = Subdomain.select("id, city as name, suffix, price, free_delivery, freedelivery_summ")
    return cities2.to_json
  end

  get 'streets.json' do
    # puts "get 'streets.json' do api.rb"
    content_type :json
    streets = Murmanskstreet.all
    return streets.to_json
  end

  get "discounts.json" do
    # puts "get discounts.json do api.rb"
    content_type :json
    return '['+@subdsc.to_json+']'
  end

  get 'overtime.json' do
    # puts "get 'overtime.json' do api.rb"
    content_type :json
    overtime_deliveries = Subdomain.find(params[:id]).overtime_deliveries
    return overtime_deliveries.to_json({
      :methods => [:start_time_short, :end_time_short]
    })
  end

  #post 'product' do
  #  puts "post product do api.rb"
#
  #  content_type :json
  #  product = Product.find_by_id(params[:id])
  #  discount_data = product.get_local_discount(@subdomain, @subdomain_pool, product.categories)
  #
  #  product._complects = product.product_complects.map do |complect|
  #    {
  #      title: complect.complect.title,
  #      header: complect.complect.header,
  #      # price: complect.price * ((100.0 - discount_data.discount_in_percents) / 100) + discount_data.discount_in_rubles,
  #      price: product.get_local_complect_price(complect.id, @subdomain, @subdomain_pool, product.categories.first),
  #      image: complect.image,
  #      id: complect.complect_id
  #    }
  #  end
#
  #  product._tags = product.tag_complects.map do |tag|
  #    {
  #      title: tag.tag.title,
  #      count: tag.count,
  #      complect: tag.complect.title
  #    }
  #  end
#
  #  product.first_category_id = product.categories.first.id
#
  #  product.promotions = Category.find(product.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
#
  #  product.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
#
  #end


  get ('/product/:id/?') do
    # puts "get /product/:id/? do API.RB"

    if request.session[:mdata].nil?
      current_date = Date.current
      session[:mdata] = Date.current
    else
      current_date = request.session[:mdata]
      session[:mdata] = request.session[:mdata]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
    end

    #session_mdata = session[:mdata]
    content_type :json
    product1 = Product.find_by_id(params[:id])
    discount_data = product1.get_local_discount(@subdomain, @subdomain_pool, product1.categories)

    product1._complects = product1.product_complects.map do |complect|
      {
        title: complect.complect.title,
        header: complect.complect.header,
        # price: complect.price * ((100.0 - discount_data.discount_in_percents) / 100) + discount_data.discount_in_rubles,
        price: product1.get_local_complect_price(product1, @subdomain, @subdomain_pool, product1.categories.first),
        image: complect.image,
        id: complect.complect_id
      }
    end

    product1._tags = product1.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end

    product1.first_category_id = product1.categories.first.id
    product1.promotions = Category.find(product1.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product1.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end

  post 'newproduct.json' do
    # puts "post newproduct.json do api.rb"
    if request.session[:mdata].nil?
      current_date = Date.current
      session[:mdata] = Date.current
    else
      current_date = request.session[:mdata]
      session[:mdata] = request.session[:mdata]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
    end

    js = JSON.parse(request.body.read)
    x_101 = [258, 978, 1145, 1183, 1208, 1244, 1255, 1580, 2204, 2230, 2282, 2335, 2367, 2445, 2447, 2499, 2500, 2501, 2553, 2568, 2581, 2585, 2725, 2728, 2746, 2834, 2835]
    special_array = [3045, 2853, 2854, 2853, 2853, 2852, 2846, 2988, 2846, 2849, 2855, 2661, 2988, 2662, 2849, 2661, 2849, 2846, 2988, 2661, 2660, 1934, 1934, 1934, 1934, 1937, 1935, 1936, 1845, 2988]
    # puts '!!!!!!!!!!!!!!!!!!!!!!!', @subdomain, '!!!!!!!!!!!!!!!!!!!!!!'

    content_type :json
    product = Product.find_by_id(js["id"])
    discount_data = product.get_local_discount(@subdomain, @subdomain_pool, product.categories)
    product._complects = product.product_complects.map do |complect|
      a = ProductComplect.where(id: complect['id'])[0]['product_id']
      if x_101.include?(a)
        # puts @subdomain
        extras = @subdomain['101roze']
      elsif special_array.include?(a)
        extras = @subdomain['ordprod']
      else
        extras = @subdomain['overprsubd']
      end

      {
        title: complect.complect.title,
        header: complect.complect.header,
        price: product.get_cmplct_price(complect.id, @subdomain.discount_pool_id, true) + extras,
        image: complect.image,
        id: complect.complect_id
      }

    end

    product._tags = product.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end
    # puts product.to_json
    product.first_category_id = product.categories.first.id
    product.promotions = Category.find(product.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end

  post 'newproduct2.json' do
    # puts "post newproduct2.json do api.rb"

    if cookies[:overcookie].nil?
      current_date = session[:mdata]
    else
      current_date = cookies[:overcookie]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    # puts session[:mdata]
    # puts current_date
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
      #@change = ProductComplect.new()
      #@change.check(value)
    end

    js = JSON.parse(request.body.read)
    content_type :json
    product2 = Product.find_by_id(js["id"])
    discount_data = product2.get_local_discount(@subdomain, @subdomain_pool, product2.categories)

    product2._complects = product2.product_complects.map do |complect|
      {
        title: complect.complect.title,
        header: complect.complect.header,
        price: product2.get_cmplct_price(complect.id, @subdomain.discount_pool_id, true),
        image: complect.image,
        id: complect.complect_id
      }

    end

    product2._tags = product2.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end

    product2.first_category_id = product2.categories.first.id
    product2.promotions = Category.find(product2.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product2.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end


  post 'cart.json' do
    # puts "post cart.json do API.RB"
      if cookies[:overcookie].nil?
        current_date = session[:mdata]
      else
        current_date = cookies[:overcookie]
      end
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      $value1 = ''
      if current_date.to_s >= date_begin and current_date.to_s <= date_end
        $value1 = 'true'
        value = 'true'
        Product.check2($value1)
        ProductComplect.check(value)
      else
        $value1 = 'false'
        value = 'false'
        Product.check2($value1)
        ProductComplect.check(value)
      end

    #session[:force] = 11
    session[:init] = true
    p session
    params = JSON.parse(request.body.read) || {}
    city_id = params['city_id']
    if city_id != @subdomain.id
      @subdomain = Subdomain.find(city_id)
      session[:subdomain] = @subdomain.id
      @subdomain_pool = SubdomainPool.find(@subdomain.subdomain_pool_id)
    end

    carts = session[:cart] || []
    products = []
    carts.each do |cart|
      product = Product.find(cart["id"])
      if product
          product.quantity = cart["quantity"]
          product.type = cart["type"]
          type_id = Complect.find_by_title(cart["type"]).id
          cmplct_id = ProductComplect.where(product_id: cart["id"], complect_id: type_id).order(created_at: :desc)[0].id
          product.discount_price = product.get_local_complect_price(cart, @subdomain, @subdomain_pool, product.categories)
          product.clean_price = product.get_local_complect_clean_price(cart, @subdomain, @subdomain_pool, product.categories)
         # product.discount_price = product.get_cmplct_price(cmplct_id, @subdomain.discount_pool_id, true)
         # product.clean_price = product.get_cmplct_price(cmplct_id, @subdomain.discount_pool_id, true)
          product.title = product_item2title(cart)
          products << product
      end
    end
    content_type :json
    products.to_json(:only => [:id, :title], :methods => [:quantity, :type, :discount_price, :clean_price])
  end

  post 'quantity.json' do
    # puts "post quantity.json do api.rb"
    js = JSON.parse(request.body.read)
    cart = session[:cart]
    cart.each_with_index do |item, index|
      if item["id"] == js["id"].to_s && (item["type"] == js["type"] || (item["type"].blank? && js["type"] == "standard" ))
        if js["method"] == "plus"
          cart[index]["quantity"] = (cart[index]["quantity"].to_i + 1).to_s
        elsif cart[index]["quantity"].to_i > 1
          cart[index]["quantity"] = (cart[index]["quantity"].to_i - 1).to_s
        end
      end
    end
    p ["QUANTITY", js]
    products = []
    content_type :json
    products.to_json
  end

  get 'default_category.json' do # для категории по умолчанию на гл.стр. поддомена (со слов бывалых)
    # puts "get default_category.json do api.rb"
    if @subdomain.enable_categories
      id = @subdomain.default_category_id
    elsif @subdomain_pool.enable_categories
      id = @subdomain_pool.default_category_id
    else
      id = 55
    end

      if request.session[:mdata].nil?
        current_date = Date.current
        session[:mdata] = Date.current
      else
        current_date = request.session[:mdata]
        session[:mdata] = request.session[:mdata]
      end
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      if current_date.to_s >= date_begin and current_date.to_s <= date_end
        value = 'true'
        ProductComplect.check(value)
      else
        value = 'false'
        ProductComplect.check(value)
        #@change = ProductComplect.new()
        #@change.check(value)
      end


    content_type :json
    {id: id}.to_json
  end

  post ('/subscribe/?') do
    # puts "post /subscribe/? do api.rb"
    @sbscrbr = Subscribers.create(
      name: params[:name],
      email: params[:email]
    )
    if @sbscrbr.save
      # erb 'Вы успешно подписались на нашу рассылку!' # redirect to '/'
      erb :'subscr/success' # redirect to '/'
    else
      erb 'Ошибка! Подписка не произведена' # redirect to '/'
    end
  end

  get ('/product-availability/:id/?') do
    # puts "get /product-availability/:id/? do api.rb"
    begin; erb Product.find(params[:id]).check_availability(@subdomain_pool).to_s
    rescue Exception => err; erb err.to_s; end
  end

  get ('/1c_exchange') do
    # puts "get /1c_exchange do api.rb"
    case params[:mode]
      when 'checkauth' then return 'success'
      when 'init' then return 'zip=no file_limit=1024000'
      when 'query'
        content_type 'text/xml'
        '<?xml version=\"2.0\" encoding=\"UTF-8\"?>'
        ord = Order.find_by_sql("SELECT * FROM orders INNER JOIN order_products ON orders.id = order_products.order_id WHERE erp_status = 0")
        # puts ord.to_xml
        doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.КоммерческаяИнформация("xmlns"=> "urn:1C.ru:commerceml_2", "ВерсияСхемы"=> "2.03", "xmlns:xs"=>"http://www.w3.org/2001/XMLSchema", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance") {
          Order.find_by_sql("SELECT * FROM orders WHERE erp_status = 0 AND oname != '#{ENV['TESTER_NAME'].to_s}'").map { |x| xml.Документ {
            #if x.region != true
            #  puts "Hello"
            #  x.region = ' '
            #end
            if x.del_address != ''
              x.district_text = x.del_address
            else
              x.district_text = x.district_text
            end

            if x.d2_date == nil
              x.d2_date = x.d1_date
            end

            xml.Ид x.eight_digit_id ? x.eight_digit_id : x.id
            xml.Номер x.eight_digit_id
            xml.ПометкаУдаления 'false'
            xml.Дата x.created_at
            xml.ХозОперация 'Заказ товара'
            xml.Роль 'Продавец'
            xml.Валюта 'руб'
            xml.ИмяПолучателя x.dname
            xml.ТелефонПолучателя x.dtel
            xml.ВремяНачала x.date_from
            xml.ВремяОкончания x.date_to
            xml.ПозвонитьПолучателю x.dcall
            xml.КакОплатить x.payment_typetext
            xml.ОставитьСоседямБукет x.ostav
            xml.ФотоВручения x.make_photo
            xml.ГородДоставки x.city
            xml.Доставка x.dt_txt
            xml.НеГоворитьЧтоЦветы x.surprise
            xml.Оплата x.payment_typetext
            xml.ДатаДоставки x.d2_date
            #xml.Представление
            xml.ТекстОткрытки x.cart
            xml.ЦенаДоставки x.delivery_price
            xml.Комментарий x.comment
            xml.Сумма x.total_summ.to_i
            xml.Контрагенты {
              xml.Контрагент {
                xml.Ид x.eight_digit_id ? x.eight_digit_id : x.id
                xml.Наименование x.oname
                xml.Контакты {
                  xml.Контакт {
                    xml.Тип 'Электронная почта'
                    xml.Значение x.email
                  }
                  xml.Контакт {
                    xml.Тип 'Телефон Рабочий'
                    xml.Значение x.otel
                  }
                }
                xml.Роль 'Покупатель'
                xml.ОфициальноеНаименование 'Сайт'
                xml.АдресДоставки{
                  xml.Представление ', 184355, ' + x.region.to_s + ', , ' + x.city.to_s + ' г , , '  + x.district_text.to_s + ', ' + x.deldom.to_s + ', ' + x.delkorpus.to_s + ', ' + x.delkvart.to_s + ',,,'
                  xml.АдресноеПоле{
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Страна'
                    xml.Значение x.country
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Город'
                    xml.Значение x.city
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Регион'
                    xml.Значение x.region
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Улица'
                    xml.Значение x.district_text
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Дом'
                    xml.Значение x.deldom
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Корпус'
                    xml.Значение x.delkorpus
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Квартира'
                    xml.Значение x.delkvart
                  }
                }
                xml.АдресРегистрации{
                  xml.Представление ', 184355, ' + x.region.to_s + ', , ' + x.city.to_s + ' г , , '  + x.district_text.to_s + ', ' + x.deldom.to_s + ', ' + x.delkorpus.to_s + ', ' + x.delkvart.to_s + ',,,'
                  xml.АдресноеПоле{
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Страна'
                    xml.Значение x.country
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Город'
                    xml.Значение x.city
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Регион'
                    xml.Значение x.region
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Улица'
                    xml.Значение x.district_text
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Дом'
                    xml.Значение x.deldom
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Корпус'
                    xml.Значение x.delkorpus
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Квартира'
                    xml.Значение x.delkvart
                  }
                }
              }
            }

            xml.Товары {
              # if x.del_price == (nil || '0')
              #   next
              # else
                xml.Товар {
                  xml.Ид '00000001'
                  xml.Наименование 'Доставка'

                  xml.ЗначенияРеквизитов {
                    xml.ЗначениеРеквизита{
                      xml.Наименование 'ВидНоменклатуры'
                      xml.Значение 'Набор'
                    }
                    xml.ЗначениеРеквизита{
                      xml.Наименование 'ТипНоменклатуры'
                      xml.Значение 'Набор'
                    }
                  }
                  xml.КомплектТовара 'Стандартная'
                  xml.БазоваяЕдиница 'компл'
                  xml.Количество '1'
                  xml.ЦенаЗаЕдиницу x.del_price
                  xml.Сумма x.del_price
                }
              # end
            Order_product.find_by_sql("SELECT *  FROM order_products WHERE order_id = " + x.id.to_s + "").each_with_index { |x|
              xml.Товар {
                xml.Ид x.product_id
                xml.Наименование x.title

                xml.ЗначенияРеквизитов {
                  xml.ЗначениеРеквизита{
                    xml.Наименование 'ВидНоменклатуры'
                    xml.Значение 'Набор'
                  }
                    xml.ЗначениеРеквизита{
                    xml.Наименование 'ТипНоменклатуры'
                    xml.Значение 'Набор'
                  }
                }
                xml.КомплектТовара x.typing
                xml.БазоваяЕдиница 'компл'
                xml.Количество x.quantity
                xml.ЦенаЗаЕдиницу x.price
                xml.Сумма x.price*x.quantity
              }
            }
          }
        } } }end
        erb doc.to_xml
      when 'success'
        Order.where(erp_status: 0).each { |x| x.erp_status = 1; x.save }
        return 'ok'
      end
  end

  get ('/smiles-for-product/:id/cndtn.json') do
    @cndtn = false
    @postsss = Smile.all
    @postsss.each do |smile|
      order = JSON.parse(smile.json_order)
      order.each do |prdct|
        @cndtn = true if prdct[1]['id'] == params[:id]
      end
    end
    content_type :json
    if @cndtn; erb '[{"res":"true"}]'
    else; erb '[{"res":"false"}]'; end
  end

  get :payment do
    erb "Text: #{params[:amount]} #{params[:desc]}"
    # redirect_to "https://www.example.com"
  end

  # API endpoint для получения данных заказа по номеру (для автозаполнения в админке)
  get '/order_info/:order_id' do
    content_type :json
    
    begin
      order_id = params[:order_id].to_i
      
      # Проверяем формат номера заказа (должен быть 8-значным числом)
      if order_id < 10_000_000 || order_id > 99_999_999
        status 400
        return { error: 'Номер заказа должен быть 8-значным числом' }.to_json
      end
      
      # Ищем заказ по eight_digit_id
      order = Order.find_by_eight_digit_id(order_id)
      
      if order.nil?
        status 404
        return { error: 'Заказ с данным номером не найден' }.to_json
      end
      
      # Возвращаем только безопасную информацию о заказе
      order_data = {
        order_id: order.eight_digit_id,
        customer_name: order.oname || '',
        order_date: order.created_at.strftime('%d.%m.%Y'),
        city: order.city || '',
        status: 'найден'
      }
      
      return order_data.to_json
      
    rescue => e
      status 500
      return { error: 'Внутренняя ошибка сервера' }.to_json
    end
  end

end

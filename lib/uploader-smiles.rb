# encoding: utf-8
class UploaderSmile < CarrierWave::Uploader::Base

  include CarrierWave::ImageOptimizer
  include CarrierWave::RMagick

  # Применяем обработку к основному файлу (не создаем оригинал)
  process :make_square_with_blur
  process optimize: [{quality: 50}]
  storage :file

  def fix_filename
    original_filename.gsub!(/\s+/, '_') if original_filename
  end

  ## Manually set root
  def root; File.join(Padrino.root,"public/"); end

  def store_dir
    'uploads/smiles'
  end

  def cache_dir
    Padrino.root("tmp")
  end

  def default_url
    "/images/cap1.png"
  end

  ##
  # White list of extensions which are allowed to be uploaded:
  #
  def extension_white_list
    %w(jpg jpeg gif png)
  end

  ##
  # Override the filename of the uploaded files
  # Создаем уникальное имя с префиксом smile_ и unix timestamp
  #
  def filename
    if original_filename && !original_filename.empty?
      # Получаем расширение из оригинального файла
      extension = File.extname(original_filename).downcase
      extension = '.jpg' if extension.empty? || !%w(.jpg .jpeg .gif .png).include?(extension)
      
      # Создаем уникальное имя: smile_unixtime.ext
      @name ||= "smile_#{Time.now.to_i}#{extension}"
    end
  end

  private

  # Метод для создания квадратного изображения с размытым фоном
  def make_square_with_blur
    manipulate! do |img|
      # Получаем размеры исходного изображения и явно приводим к integer
      width = img.columns.to_i
      height = img.rows.to_i
      
      # Определяем большую и меньшую стороны
      x = [width, height].max.to_i
      y = [width, height].min.to_i
      
      # Проверяем, квадратное ли изображение
      if width == height
        puts "DEBUG UPLOADER: Изображение уже квадратное (#{width}x#{height}), обработка пропущена"
        return img
      end
      
      puts "DEBUG UPLOADER: Обработка изображения #{width}x#{height} -> #{x}x#{x}"
      puts "DEBUG UPLOADER: Создается файл с именем: #{filename}" if respond_to?(:filename)
      
      # Сохраняем копию оригинального изображения для наложения
      original_for_overlay = img.dup
      
      # Шаг 1: Создаем фоновое изображение
      # Увеличиваем масштаб так, чтобы меньшая сторона стала равна x
      scale_factor = x.to_f / y.to_f
      
      puts "DEBUG UPLOADER: width.class=#{width.class}, height.class=#{height.class}, x.class=#{x.class}, y.class=#{y.class}, scale_factor=#{scale_factor}"
      
      if width > height
        # Пейзажная ориентация: увеличиваем по высоте
        new_width = (width * scale_factor).to_i
        background_img = img.resize(new_width, x)
      else
        # Портретная ориентация: увеличиваем по ширине
        new_height = (height * scale_factor).to_i
        background_img = img.resize(x, new_height)
      end
      
      # Обрезаем до квадрата по центру
      background_img = background_img.crop(Magick::CenterGravity, x, x)
      
      # Шаг 2: Применяем размытие к фону
      background_img = background_img.blur_image(8, 3) # radius=8, sigma=3
      
      # Шаг 3: Накладываем оригинальное изображение по центру
      # Вычисляем позицию для размещения по центру
      overlay_x = (x - width) / 2
      overlay_y = (x - height) / 2
      
      # Накладываем оригинал на размытый фон
      result = background_img.composite(original_for_overlay, overlay_x, overlay_y, Magick::OverCompositeOp)
      
      puts "DEBUG UPLOADER: Квадратное изображение с размытым фоном создано: #{result.columns}x#{result.rows}"
      puts "DEBUG UPLOADER: Финальное имя файла: #{filename}" if respond_to?(:filename)
      
      result
    end
  end

end

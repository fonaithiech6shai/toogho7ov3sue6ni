# encoding: utf-8
Rozario::App.helpers do
  # def simple_helper_method
  #  ...
  # end
  def wrap_seo_params(params_hash)
    result_hash = params_hash.clone
    known_inserts = {}
    #insert params by id
    result_hash.each_value do |v|
      next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String)
      v.scan(/%pattern\d+%/i).each do |entry|

        id = entry.match(/\d+/)[0].to_s.to_i
        # raise id.inspect
        result = Pattern.where(id: id)
        data_to_replace = ''
        if result.length > 0
          data_to_replace = result.first.content
        end
        v.sub!(entry, data_to_replace)
      end
    end
    # raise result_hash.inspect
    #insert subdomains values
    # @subdomain = Subdomain.all.first
    if @subdomain
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String)
        v.gsub!(/%city%/, "#{@subdomain.city}")
        v.gsub!(/%in_city%/, "в #{@subdomain.city}")
        v.gsub!(/%suffix%/, "#{@subdomain.suffix}")
        v.gsub!(/%morph%/, "#{@subdomain.get_morph('loc2')}")
      	v.gsub!(/%morph_datel%/, "#{@subdomain.morph_datel}")
      	v.gsub!(/%morph_predl%/, "#{@subdomain.morph_predl}")
      	v.gsub!(/%morph_rodit%/, "#{@subdomain.morph_rodit}")
      end
    end

    if @products
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String) || @products.kind_of?(Array)
        v.gsub!(/%h%/, "#{@products.header}")
      end
    end
    
    if @product || @page || @product
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter

      end
    end
    #insert categories and tags if product
    #insert bu slug
    # raise @subdomain.
    if @product
      # raise @product.categories.inspect
      categories = @product.categories.map(&:title).map(&:strip).uniq.join(', ')
      tags = @product.tags.map(&:title).map(&:strip).uniq.join(', ')
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String) || @product.kind_of?(Array)
        v.gsub!(/%categories%/, "#{categories}")
        v.gsub!(/%tags%/, "#{tags}")
      end
    end

    if @article || @category || @news || @smile || @product || @products
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String) || @news.kind_of?(Array)
        v.gsub!(/%header%/, "#{@article.title}") if @article
        v.gsub!(/%header%/, "#{@category.title}") if @category
        v.gsub!(/%header%/, "#{@news.title}") if @news
        v.gsub!(/%header%/, "#{@smile.title}") if @smile
        v.gsub!(/%header%/, "#{@products.header}") if @products
        v.gsub!(/%header%/, "#{@product.header}") if @product
        v.gsub!(/%header%/, "#{@page.header}") if @page
      end
    end

    # Special variables for smiles only
    if @smile
      result_hash.each_value do |v|
        next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String)
        
        # %customer_name% - Имя клиента
        customer_name = @smile.customer_name || "Покупатель"
        v.gsub!(/%customer_name%/, customer_name)
        
        # %recipient_name% - Имя получателя из поля dname заказа
        recipient_name = @smile.recipient_name || ""
        v.gsub!(/%recipient_name%/, recipient_name)
        
        # %main_product_name% - Название букета (использует новую логику products_data)
        main_product_name = ""
        begin
          # Используем новую логику products_data (приоритет: order_data > json_order)
          products_data = @smile.products_data
          
          if products_data && products_data.is_a?(Hash) && !products_data.empty?
            # Получаем первый товар
            first_item = products_data['0'] || products_data[0]
            
            if first_item && first_item['title'] && !first_item['title'].to_s.strip.empty?
              # Используем title из данных (может быть из order_products или json_order)
              main_product_name = first_item['title'].to_s
            elsif first_item && first_item['id']
              # Fallback: получаем актуальное название товара из Product
              product_id = first_item['id'].to_i
              product = Product.find_by_id(product_id)
              main_product_name = product.header.to_s if product && product.header && !product.header.to_s.strip.empty?
            end
          end
        rescue => e
          # В случае ошибки оставляем пустую строку
        end
        v.gsub!(/%main_product_name%/, main_product_name)
        
        # %date_smile% - Дата из поля date
        date_smile = @smile.date || ""
        v.gsub!(/%date_smile%/, date_smile)
        
        # %order_eight_digit_id% - Номер заказа
        order_id = @smile.order_eight_digit_id ? @smile.order_eight_digit_id.to_s : ""
        v.gsub!(/%order_eight_digit_id%/, order_id)
      end
    end

    # raise result_hash.inspect
    result_hash.each_value do |v|
      next if v.nil? || v.class == UploaderOg || v.class == UploaderTwitter || !v.is_a?(String)
      v.scan(/%\w+%/).uniq.each do |pattern|
        slug = pattern.gsub('%', '')
        string_to_replace = ''
        patterns = Pattern.where(slug: slug)
        if patterns.length > 0
          string_to_replace = patterns.first.content
        end
        v.gsub!(pattern, "#{string_to_replace}")
      end
    end
    result_hash
  end

  def set_seo_tags_for_page(page)
    wrap_seo_params(
      title: page.title,
      description: page.description,
      # keywords: page.keywords,
      h1: page.h1,
      og_type: page.og_type,
      og_title: page.og_title,
      og_description: page.og_description,
      og_site_name: page.og_site_name,
      twitter_title: page.twitter_title,
      twitter_description: page.twitter_description,
      twitter_site: page.twitter_site,
      twitter_image_alt: page.twitter_image_alt,
      twitter_image: page.twitter_image,
      og_image: page.og_image
    )
  end
end
def get_seo_data(page, id = nil, index = false)

  x = id.present? ? Seo.find(id) : nil
  seo = set_seo_tags_for_page(x) if x
  def_seo = set_seo_tags_for_page(SeoGeneral.find_by_name(page)) if SeoGeneral.find_by_name(page).present?
  all_seo = set_seo_tags_for_page(SeoGeneral.find_by_name('default')) if SeoGeneral.find_by_name('default').present?

  @seo = {index: x ? x.index : index }
  
  # Store general SEO data for dynamic schema generation
  @general_seo_data = def_seo if def_seo

  seo     &&  seo[:title].present?     ? @seo[:title] = seo[:title]      :
  def_seo &&  def_seo[:title].present? ? @seo[:title] = def_seo[:title]  :
  all_seo &&  all_seo[:title].present? ? @seo[:title] = all_seo[:title]  : ''

  seo     &&  seo[:description].present?     ? @seo[:description] = seo[:description]      :
  def_seo &&  def_seo[:description].present? ? @seo[:description] = def_seo[:description]  :
  all_seo &&  all_seo[:description].present? ? @seo[:description] = all_seo[:description]  : ''

  # seo     &&  seo[:keywords].present?     ? @seo[:keywords] = seo[:keywords]      :
  # def_seo &&  def_seo[:keywords].present? ? @seo[:keywords] = def_seo[:keywords]  :
  # all_seo &&  all_seo[:keywords].present? ? @seo[:keywords] = all_seo[:keywords]  : ''

  seo     &&  seo[:og_type].present?     ? @seo[:og_type] = seo[:og_type]      :
  def_seo &&  def_seo[:og_type].present? ? @seo[:og_type] = def_seo[:og_type]  :
  all_seo &&  all_seo[:og_type].present? ? @seo[:og_type] = all_seo[:og_type]  : 'website'

  seo     &&  seo[:og_title].present?     ? @seo[:og_title] = seo[:og_title]      :
  def_seo &&  def_seo[:og_title].present? ? @seo[:og_title] = def_seo[:og_title]  :
  all_seo &&  all_seo[:og_title].present? ? @seo[:og_title] = all_seo[:og_title]  : ''

  seo     &&  seo[:og_description].present?     ? @seo[:og_description] = seo[:og_description]      :
  def_seo &&  def_seo[:og_description].present? ? @seo[:og_description] = def_seo[:og_description]  :
  all_seo &&  all_seo[:og_description].present? ? @seo[:og_description] = all_seo[:og_description]  : ''

  seo     &&  seo[:og_image].url     ? @seo[:og_image] = options.host + seo[:og_image].url      :
  def_seo &&  def_seo[:og_image].url ? @seo[:og_image] = options.host + def_seo[:og_image].url  :
  all_seo &&  all_seo[:og_image].url ? @seo[:og_image] = options.host + all_seo[:og_image].url  : ''

  seo     &&  seo[:twitter_title].present?     ? @seo[:twitter_title] = seo[:twitter_title]      :
  def_seo &&  def_seo[:twitter_title].present? ? @seo[:twitter_title] = def_seo[:twitter_title]  :
  all_seo &&  all_seo[:twitter_title].present? ? @seo[:twitter_title] = all_seo[:twitter_title]  : ''

  seo     &&  seo[:twitter_description].present?     ? @seo[:twitter_description] = seo[:twitter_description]      :
  def_seo &&  def_seo[:twitter_description].present? ? @seo[:twitter_description] = def_seo[:twitter_description]  :
  all_seo &&  all_seo[:twitter_description].present? ? @seo[:twitter_description] = all_seo[:twitter_description]  : ''

  seo     &&  seo[:twitter_image].url     ? @seo[:twitter_image] = options.host + seo[:twitter_image].url       :
  def_seo &&  def_seo[:twitter_image].url ? @seo[:twitter_image] = options.host + def_seo[:twitter_image].url   :
  all_seo &&  all_seo[:twitter_image].url ? @seo[:twitter_image] = options.host + all_seo[:twitter_image].url   : ''

  if index || x && x.index
    seo     &&  seo[:h1].present?     ? @seo[:h1] = seo[:h1]      :
    def_seo &&  def_seo[:h1].present? ? @seo[:h1] = def_seo[:h1]  :
    all_seo &&  all_seo[:h1].present? ? @seo[:h1] = all_seo[:h1]  : ''
  end
  
  # Process variables for all SEO fields
  @seo = wrap_seo_params(@seo)
end
  # Generate custom title for smiles pages
  # Format: «[Product Name]» – фото доставки, [Date]
  def generate_smile_title(smile_id)
    return nil unless smile_id
    
    post = Smile.find_by_id(smile_id)
    return nil unless post && post.json_order && !post.json_order.empty?
    
    begin
      # Extract product name from json_order (structure: {"0": {"id": "product_id", "complect": "..."}} or [{"id": product_id, "title": "product_title", ...}])
      order_data = JSON.parse(post.json_order)
      
      # Handle both object with "0" key and array formats
      first_item = nil
      if order_data.is_a?(Hash) && order_data['0']
        first_item = order_data['0']
      elsif order_data.is_a?(Array) && order_data[0]
        first_item = order_data[0]
      end
      
      if first_item && first_item['title'] && !first_item['title'].to_s.strip.empty?
        # Use title directly from json_order
        clean_product_name = first_item['title'].to_s.strip
        formatted_date = post.date || post.created_at.strftime('%d.%m.%Y')
        return "«#{clean_product_name}» – фото доставки, #{formatted_date}"
      elsif first_item && first_item['id']
        # Fallback: try to get product by ID if title is not available
        product_id = first_item['id'].to_i
        product = Product.find_by_id(product_id)
        
        if product && product.header && !product.header.to_s.strip.empty?
          clean_product_name = product.header.to_s.strip
          formatted_date = post.date || post.created_at.strftime('%d.%m.%Y')
          return "«#{clean_product_name}» – фото доставки, #{formatted_date}"
        end
      end
    rescue => e
      # Return nil if anything goes wrong
      return nil
    end
    
    nil
  end
  # Clean HTML entities and non-breaking spaces from SEO description
  def clean_seo_description(description)
    return nil unless description
    return description unless description.is_a?(String)
    
    # Replace non-breaking space (U+00A0, <0xa0>) with normal space
    cleaned = description.gsub(/\u00A0/, ' ')   # Unicode non-breaking space (regex form)
                        .gsub('&nbsp;', ' ')   # HTML entity
                        .gsub('&amp;', '&')
                        .gsub('&lt;', '<')
                        .gsub('&gt;', '>')
                        .gsub('&quot;', '"')
                        .gsub('&#39;', "'")
                        .gsub('&apos;', "'")
    
    # Clean up extra whitespace
    cleaned.gsub(/\s+/, ' ').strip
  end
  # Generate custom description for smiles pages
  # Format: Фото с доставки «[Product Name]», [Date]. [Original description]
  def generate_smile_description(smile_id, original_description = nil)
    return original_description unless smile_id
    
    post = Smile.find_by_id(smile_id)
    return original_description unless post && post.json_order && !post.json_order.empty?
    
    begin
      # Extract product name from json_order (structure: {"0": {"id": "product_id", "complect": "..."}} or [{"id": product_id, "title": "product_title", ...}])
      order_data = JSON.parse(post.json_order)
      
      # Handle both object with "0" key and array formats
      first_item = nil
      if order_data.is_a?(Hash) && order_data['0']
        first_item = order_data['0']
      elsif order_data.is_a?(Array) && order_data[0]
        first_item = order_data[0]
      end
      
      if first_item && first_item['title'] && !first_item['title'].to_s.strip.empty?
        # Use title directly from json_order
        clean_product_name = first_item['title'].to_s.strip
        formatted_date = post.date || post.created_at.strftime('%d.%m.%Y')
        
        # Build prefix without customer name
        prefix = "Фото с доставки \u00ab#{clean_product_name}\u00bb, #{formatted_date}"
        
        if original_description && !original_description.empty?
          return "#{prefix}. #{original_description}"
        else
          return prefix
        end
      elsif first_item && first_item['id']
        # Fallback: try to get product by ID if title is not available
        product_id = first_item['id'].to_i
        product = Product.find_by_id(product_id)
        
        if product && product.header && !product.header.to_s.strip.empty?
          clean_product_name = product.header.to_s.strip
          formatted_date = post.date || post.created_at.strftime('%d.%m.%Y')
          
          prefix = "Фото с доставки \u00ab#{clean_product_name}\u00bb, #{formatted_date}"
          
          if original_description && !original_description.empty?
            return "#{prefix}. #{original_description}"
          else
            return prefix
          end
        end
      end
    rescue => e
      # Return original description if anything goes wrong
      return original_description
    end
    
    original_description
  end
  # Process smile title with variable substitution
  def process_smile_title(smile)
    return '' unless smile && smile.title
    
    # Store current @smile for wrap_seo_params context
    original_smile = @smile
    @smile = smile
    
    # Process the title through wrap_seo_params
    processed = wrap_seo_params({ title: smile.title })
    
    # Restore original @smile context
    @smile = original_smile
    
    processed[:title] || smile.title
  end
  
  # Process smile body with variable substitution
  def process_smile_body(smile)
    return '' unless smile && smile.body
    
    # Store current @smile for wrap_seo_params context
    original_smile = @smile
    @smile = smile
    
    # Process the body through wrap_seo_params
    processed = wrap_seo_params({ body: smile.body })
    
    # Restore original @smile context
    @smile = original_smile
    
    processed[:body] || smile.body
  end
  
  # Process smile alt with variable substitution
  def process_smile_alt(smile)
    return '' unless smile && smile.alt
    
    # Store current @smile for wrap_seo_params context
    original_smile = @smile
    @smile = smile
    
    # Process the alt through wrap_seo_params
    processed = wrap_seo_params({ alt: smile.alt })
    
    # Restore original @smile context
    @smile = original_smile
    
    processed[:alt] || smile.alt
  end
  
  # Безопасное получение изображения smile с проверкой на nil и существование файла
  def get_smile_image_path(smile)
    return nil unless smile && smile.images.present? && smile.images.current_path.present?
    
    begin
      current_path = smile.images.current_path
      filename = File.basename(current_path)
      
      # Проверяем существование файла в указанных директориях
      image_paths = [
        "/srv/grunt/dest/uploads/smile/#{filename}",
        "/srv/grunt/dest/uploads/smiles/#{filename}",
        "/srv/public/uploads/smile/#{filename}",
        "/srv/public/uploads/smiles/#{filename}"
      ]
      
      # Находим первый существующий файл
      existing_path = image_paths.find { |path| File.exist?(path) }
      
      if existing_path
        # Возвращаем относительный web-путь к файлу
        web_path = existing_path.gsub(/^\/srv\/(grunt\/dest|public)/, '')
        return web_path
      else
        # Файл не найден ни в одной директории
        return nil
      end
    rescue => e
      # Логируем ошибку и возвращаем nil
      Rails.logger.error "Error processing smile image for smile #{smile.id}: #{e.message}" if defined?(Rails)
      nil
    end
  end
  
  # Проверяет, есть ли у smile доступное изображение
  def smile_has_image?(smile)
    !get_smile_image_path(smile).nil?
  end
  
  # Generate dynamic schema.org Review microdata for smiles with SEO fallback

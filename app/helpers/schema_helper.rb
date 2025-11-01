# encoding: utf-8

# Helper methods for generating Schema.org markup
Rozario::App.helpers do
  
  # Helper method to check if value is blank (nil, empty, or whitespace)
  def blank?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.respond_to?(:strip) && value.strip.empty?)
  end
  
  # Helper method to check if value is present (not blank)
  def present?(value)
    !blank?(value)
  end
  
  # Generates Schema.org ImageObject JSON-LD script tag
  def generate_image_schema(image_url, options = {})
    schema_data = {
      "@context" => "https://schema.org",
      "@type" => "ImageObject",
      "contentUrl" => image_url
    }
    
    # Add optional fields if provided
    schema_data["name"] = options[:name] if options[:name]
    schema_data["description"] = options[:description] if options[:description] 
    schema_data["datePublished"] = options[:date_published] if options[:date_published]
    schema_data["width"] = options[:width] if options[:width]
    schema_data["height"] = options[:height] if options[:height]
    schema_data["author"] = options[:author] || "Rozario Flowers"
    
    content_tag(:script, 
                JSON.pretty_generate(schema_data).html_safe, 
                type: "application/ld+json")
  end
  
  # Generate schema for product images
  def product_image_schema(product, mobile = false)
    return "" unless product.respond_to?(:thumb_image)
    
    begin
      image_url = full_image_url(product.thumb_image(mobile))
      return "" if blank?(image_url)
      
      options = {
        name: product.respond_to?(:header) ? product.header : "Product Image",
        description: (product.respond_to?(:alt) && present?(product.alt)) ? product.alt : (product.respond_to?(:header) ? product.header : "Product Image"),
        date_published: product.respond_to?(:created_at) ? product.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      # Try to get image dimensions if available 
      # Note: dimensions are hardcoded as requested, 
      # but could be extracted from actual image files
      if mobile
        options[:width] = "650"
        options[:height] = "650"
      else
        options[:width] = "1315"
        options[:height] = "650"
      end
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  
  # Generate schema for smile/review images with safe handling
  def smile_image_schema(smile, alt_text = nil)
    return "" unless smile && smile.respond_to?(:images_identifier) && present?(smile.images_identifier)
    
    begin
      # Используем get_smile_image_path для проверки существования и правильного пути
      image_path = get_smile_image_path(smile)
      return "" if blank?(image_path)
      
      image_url = full_image_url(image_path)
      return "" if blank?(image_url)
      
      # Use provided alt_text or construct safe fallback
      name = alt_text || (smile.respond_to?(:title) && present?(smile.title) ? smile.title : "Отзыв покупателя")
      description = alt_text || name
      
      options = {
        name: name,
        description: description,
        date_published: (smile.respond_to?(:created_at) && smile.created_at) ? smile.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate schema for category images
  def category_image_schema(category)
    return "" unless category.respond_to?(:image)
    
    begin
      image_url = full_image_url(category.image)
      return "" if blank?(image_url)
      
      options = {
        name: category.respond_to?(:title) ? category.title : "Категория товаров",
        description: category.respond_to?(:title) ? category.title : "Категория товаров",
        date_published: category.respond_to?(:created_at) ? category.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate schema for product modal images (with Angular image URL)
  def product_modal_image_schema(product, angular_image_var = nil)
    return "" unless product
    
    begin
      # For modal images, we might use Angular variables or product image
      if angular_image_var
        # Use the Angular variable as-is for contentUrl - it will be resolved on client side
        image_url = "{{ #{angular_image_var} }}"
      else
        image_url = full_image_url(product.respond_to?(:thumb_image) ? product.thumb_image(false) : "")
        return "" if blank?(image_url)
      end
      
      options = {
        name: product.respond_to?(:header) ? product.header : "Product Image",
        description: (product.respond_to?(:alt) && present?(product.alt)) ? product.alt : (product.respond_to?(:header) ? product.header : "Product Image"),
        date_published: product.respond_to?(:created_at) ? product.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      # For desktop images in modal
      options[:width] = "900"
      options[:height] = "650"
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate schema for complex product images (from perekrestok template)
  def complex_product_image_schema(product, image_url)
    return "" unless product && present?(image_url)
    
    begin
      full_url = full_image_url(image_url)
      return "" if blank?(full_url)
      
      options = {
        name: product.respond_to?(:header) ? product.header : "Product Image",
        description: (product.respond_to?(:alt) && present?(product.alt)) ? product.alt : (product.respond_to?(:header) ? product.header : "Product Image"),
        date_published: product.respond_to?(:created_at) ? product.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      # Standard product image dimensions
      options[:width] = "650"
      options[:height] = "650"
      
      generate_image_schema(full_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate schema for news/article images
  def news_image_schema(news)
    return "" unless news.respond_to?(:image)
    
    begin
      image_url = full_image_url(news.image)
      return "" if blank?(image_url)
      
      options = {
        name: news.respond_to?(:title) ? news.title : "Новость",
        description: news.respond_to?(:title) ? news.title : "Новость",
        date_published: news.respond_to?(:created_at) ? news.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate schema for slideshow slides
  def slide_image_schema(slide)
    return "" unless slide.respond_to?(:image)
    
    begin
      image_url = full_image_url(slide.image)
      return "" if blank?(image_url)
      
      options = {
        name: (slide.respond_to?(:text) && present?(slide.text)) ? slide.text : "Slideshow Image",
        description: (slide.respond_to?(:text) && present?(slide.text)) ? slide.text : "Slideshow Image",
        date_published: slide.respond_to?(:created_at) ? slide.created_at.strftime("%Y-%m-%d") : Date.current.strftime("%Y-%m-%d"),
        author: "Rozario Flowers"
      }
      
      generate_image_schema(image_url, options)
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate CollectionPage schema for catalog and category pages
  def collection_page_schema(options = {})
    begin
      canonical_url = options[:url] || (@canonical || "")
      return "" if blank?(canonical_url)
      
      schema_data = {
        "@context" => "https://schema.org",
        "@type" => "CollectionPage",
        "url" => canonical_url
      }
      
      # Add required fields
      schema_data["name"] = options[:name] if present?(options[:name])
      schema_data["description"] = options[:description] if present?(options[:description])
      schema_data["about"] = options[:about] if present?(options[:about])
      
      # Add datePublished and dateModified if available
      schema_data["datePublished"] = options[:date_published] if present?(options[:date_published])
      schema_data["dateModified"] = options[:date_modified] if present?(options[:date_modified])
      
      # Add author
      schema_data["author"] = options[:author] || {
        "@type" => "Organization",
        "name" => "Rozario Flowers"
      }
      
      # Add breadcrumb navigation if provided
      if options[:breadcrumbs] && options[:breadcrumbs].is_a?(Array)
        breadcrumb_list = {
          "@type" => "BreadcrumbList",
          "itemListElement" => options[:breadcrumbs].map.with_index do |item, index|
            {
              "@type" => "ListItem",
              "position" => index + 1,
              "item" => {
                "@id" => item[:url],
                "name" => item[:name]
              }
            }
          end
        }
        schema_data["breadcrumb"] = breadcrumb_list
      end
      
      # Add mainEntity if items are provided
      if options[:items] && options[:items].is_a?(Array) && !options[:items].empty?
        item_list = {
          "@type" => "ItemList",
          "numberOfItems" => options[:items].size,
          "itemListElement" => options[:items].first(10).map.with_index do |item, index| # Limit to first 10 items for performance
            list_item = {
              "@type" => "ListItem",
              "position" => index + 1
            }
            
            if item.respond_to?(:header) && item.respond_to?(:id)
              # For Product objects
              product_url = "#{canonical_url.chomp('/')}/product/#{item.respond_to?(:slug) && present?(item.slug) ? item.slug : item.id}"
              product_url = product_url.gsub(/\/{2,}/, '/').gsub(/\/$/, '') # Clean up double slashes
              list_item["item"] = {
                "@type" => "Product",
                "@id" => product_url,
                "name" => item.header,
                "url" => product_url
              }
              
              # Add image if available
              if item.respond_to?(:thumb_image)
                image_url = full_image_url(item.thumb_image(false))
                list_item["item"]["image"] = image_url if present?(image_url)
              end
              
              # Add price if available
              if item.respond_to?(:get_minimal_price)
                begin
                  price = item.get_minimal_price(@subdomain.try(:discount_pool_id))
                  if price && price > 0
                    list_item["item"]["offers"] = {
                      "@type" => "Offer",
                      "price" => price.to_s,
                      "priceCurrency" => "RUB",
                      "availability" => "https://schema.org/InStock"
                    }
                  end
                rescue
                  # Skip price if error occurs
                end
              end
            elsif item.respond_to?(:title)
              # For Category objects or other items with title
              item_url = "#{canonical_url.chomp('/')}/category/#{item.respond_to?(:slug) && present?(item.slug) ? item.slug : item.id}"
              item_url = item_url.gsub(/\/{2,}/, '/').gsub(/\/$/, '') # Clean up double slashes
              list_item["item"] = {
                "@type" => "Thing",
                "@id" => item_url,
                "name" => item.title,
                "url" => item_url
              }
            end
            
            list_item
          end
        }
        schema_data["mainEntity"] = item_list
      end
      
      content_tag(:script, 
                  JSON.pretty_generate(schema_data).html_safe, 
                  type: "application/ld+json")
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate enhanced WebPage schema
  def webpage_schema(options = {})
    begin
      canonical_url = options[:url] || (@canonical || "")
      return "" if blank?(canonical_url)
      
      schema_data = {
        "@context" => "https://schema.org",
        "@type" => "WebPage",
        "url" => canonical_url
      }
      
      # Add required fields
      schema_data["name"] = options[:name] if present?(options[:name])
      schema_data["description"] = options[:description] if present?(options[:description])
      
      # Add optional fields
      schema_data["datePublished"] = options[:date_published] if present?(options[:date_published])
      schema_data["dateModified"] = options[:date_modified] if present?(options[:date_modified])
      schema_data["author"] = options[:author] || {
        "@type" => "Organization",
        "name" => "Rozario Flowers"
      }
      
      # Add breadcrumb navigation if provided
      if options[:breadcrumbs] && options[:breadcrumbs].is_a?(Array)
        breadcrumb_list = {
          "@type" => "BreadcrumbList",
          "itemListElement" => options[:breadcrumbs].map.with_index do |item, index|
            {
              "@type" => "ListItem",
              "position" => index + 1,
              "item" => {
                "@id" => item[:url],
                "name" => item[:name]
              }
            }
          end
        }
        schema_data["breadcrumb"] = breadcrumb_list
      end
      
      # Add main entity if provided
      schema_data["mainEntity"] = options[:main_entity] if options[:main_entity]
      
      # Add isPartOf to link to website
      if @subdomain && @subdomain.respond_to?(:url)
        current_domain = CURRENT_DOMAIN
        website_url = @subdomain.url != 'murmansk' ? "https://#{@subdomain.url}.#{current_domain}" : "https://#{current_domain}"
        schema_data["isPartOf"] = {
          "@type" => "WebSite",
          "@id" => "#{website_url}/#website",
          "url" => website_url,
          "name" => options[:website_name] || (defined?(@title) ? @title : "Rozario Flowers")
        }
      end
      
      content_tag(:script, 
                  JSON.pretty_generate(schema_data).html_safe, 
                  type: "application/ld+json")
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate BreadcrumbList schema
  def breadcrumb_schema(items)
    return "" unless items && items.is_a?(Array) && !items.empty?
    
    begin
      schema_data = {
        "@context" => "https://schema.org",
        "@type" => "BreadcrumbList",
        "itemListElement" => items.map.with_index do |item, index|
          {
            "@type" => "ListItem",
            "position" => index + 1,
            "item" => {
              "@id" => item[:url],
              "name" => item[:name]
            }
          }
        end
      }
      
      content_tag(:script, 
                  JSON.pretty_generate(schema_data).html_safe, 
                  type: "application/ld+json")
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  private
  
  # Convert relative image URL to full URL
  def full_image_url(image_path)
    return "" if image_path.nil? || (image_path.respond_to?(:empty?) && image_path.empty?)
    
    begin
      image_path_str = image_path.to_s
      return "" if image_path_str.empty?
      
      # If it's already a full URL, return as is
      return image_path_str if image_path_str.start_with?('http')
      
      # Otherwise, construct full URL with proper murmansk handling
      current_domain = CURRENT_DOMAIN
      
      if @subdomain && @subdomain.respond_to?(:url) && @subdomain.url != 'murmansk'
        base_url = "https://#{@subdomain.url}.#{current_domain}"
      else
        base_url = "https://#{current_domain}"
      end
      
      image_path_str.start_with?('/') ? "#{base_url}#{image_path_str}" : "#{base_url}/#{image_path_str}"
    rescue => e
      ""
    end
  end
end


  # Generate Organization/Florist schema for current subdomain
  def organization_florist_schema(options = {})
    begin
      return "" unless @subdomain
      
      # Determine the organization type
      org_type = options[:type] || "Florist"
      
      # Build the base URL dynamically
      current_domain = Rozario::App::CURRENT_DOMAIN
      website_url = @subdomain.url != 'murmansk' ? "https://#{@subdomain.url}.#{current_domain}" : "https://#{current_domain}"
      
      # Build the schema data
      schema_data = {
        "@context" => "https://schema.org",
        "@type" => org_type,
        "name" => "Rozario Flowers",
        "url" => website_url,
        "logo" => "https://#{current_domain}/logo.png"
      }
      
      # Add address information
      if address_data = build_address_data
        schema_data["address"] = address_data
      end
      
      # Add contact point information  
      if contact_data = build_contact_data
        schema_data["contactPoint"] = contact_data
      end
      
      # Add additional properties if provided
      schema_data["priceRange"] = options[:price_range] || "RUB"
      schema_data["paymentAccepted"] = options[:payment_accepted] || ["Cash", "Credit Card"]
      
      if options[:opening_hours]
        schema_data["openingHours"] = options[:opening_hours]
      else
        schema_data["openingHours"] = "Mo-Su 00:00-23:59"  # 24/7 as default
      end
      
      content_tag(:script, 
                  JSON.pretty_generate(schema_data).html_safe, 
                  type: "application/ld+json")
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  # Generate Organization/Florist microdata attributes for footer
  def organization_microdata_attributes(options = {})
    return {} unless @subdomain
    
    # Build address for itemProp
    address = @subdomain.ya_address.present? ? @subdomain.ya_address : "Ростинская 9а"
    
    # Find phone number
    phone = find_subdomain_telephone || "+7 (800) 250-64-70"
    
    {
      address: address,
      telephone: phone,
      name: "Розарио Доставка №1",
      opening_hours: "Mo-Su",
      payment_accepted: "credit card",
      email: "info@rozariofl.ru"
    }
  end
  
  private
  
  # Build address data for the current subdomain
  def build_address_data
    return nil unless @subdomain
    
    # Extract city information
    city = @subdomain.city || "Мурманск"
    
    address_data = {
      "@type" => "PostalAddress",
      "addressLocality" => city
    }
    
    # Extract region from suffix if available
    if @subdomain.suffix.present?
      region = extract_region_from_suffix(@subdomain.suffix) 
      address_data["addressRegion"] = region if region
      
      # Set country based on suffix
      address_data["addressCountry"] = extract_country_from_suffix(@subdomain.suffix)
    else
      address_data["addressCountry"] = "РУ"  # Default to Russia
    end
    
    # Add street address if available from ya_address or other sources
    if @subdomain.ya_address.present?
      address_data["streetAddress"] = @subdomain.ya_address
    elsif @subdomain.contact && @subdomain.contact.enabled && extract_address_from_contact
      address_data["streetAddress"] = extract_address_from_contact
    end
    
    address_data
  end
  
  # Build contact point data for the current subdomain
  def build_contact_data
    contact_data = {
      "@type" => "ContactPoint",
      "contactType" => "customer support",
      "areaServed" => "RU",
      "availableLanguage" => "Russian"
    }
    
    # Try to get telephone from various sources
    phone = find_subdomain_telephone
    if phone
      contact_data["telephone"] = phone
    else
      # Default fallback phone
      contact_data["telephone"] = "+7 (800) 250-64-70"
    end
    
    contact_data
  end
  
  # Extract region from subdomain suffix (e.g., ", Московская область, Россия")
  def extract_region_from_suffix(suffix)
    return nil unless suffix && suffix.is_a?(String)
    
    # Remove leading comma and space, split by commas
    parts = suffix.gsub(/^,\s*/, '').split(',').map(&:strip)
    
    # If we have at least 2 parts and the last is "Россия", return the second-to-last
    if parts.length >= 2 && parts.last == "Россия"
      return parts[-2] unless parts[-2].empty?
    end
    
    # If we have 1 part and it's not "Россия", return it (e.g., ", Франция")
    if parts.length == 1 && parts.first != "Россия"
      return nil  # For foreign countries, we don't have region info in schema.org format
    end
    
    nil
  end
  
  # Get country from subdomain suffix
  def extract_country_from_suffix(suffix)
    return "РУ" unless suffix && suffix.is_a?(String)  # Default to Russia
    
    parts = suffix.gsub(/^,\s*/, '').split(',').map(&:strip)
    
    # Map some countries to their ISO codes
    country_map = {
      "Россия" => "РУ",
      "Франция" => "FR",
      "Казахстан" => "KZ",
      "Беларусь" => "BY",
      "Украина" => "UA"
    }
    
    country_name = parts.last
    return country_map[country_name] || "РУ"
  end
  
  # Find telephone number for current subdomain
  def find_subdomain_telephone
    # Try to get from subdomain's contact if available
    if @subdomain.contact && @subdomain.contact.enabled
      phone = extract_phone_from_contact(@subdomain.contact)
      return phone if phone
    end
    
    # Try to get from general contact info
    general_contact = Contact.first
    if general_contact
      phone = extract_phone_from_contact(general_contact)
      return phone if phone
    end
    
    nil
  end
  
  # Extract address from contact body or other fields
  def extract_address_from_contact
    return nil unless @subdomain.contact && @subdomain.contact.enabled
    
    # Try to extract address from contact body using regex
    body = @subdomain.contact.body
    return nil unless body
    
    # Simple regex to find address patterns
    address_patterns = [
      /(?:ул|улица)[\s\.]*([^,\n]+)/i,
      /(?:пр|проспект)[\s\.]*([^,\n]+)/i,
      /(?:наб|набережная)[\s\.]*([^,\n]+)/i
    ]
    
    address_patterns.each do |pattern|
      if match = body.match(pattern)
        return match[0].strip
      end
    end
    
    nil
  end
  
  # Extract phone from contact body or other fields
  def extract_phone_from_contact(contact)
    return nil unless contact.body
    
    # Phone number patterns
    phone_patterns = [
      /\+7[\s\-\(\)]*(\d{3})[\s\-\(\)]*(\d{3})[\s\-\(\)]*(\d{2})[\s\-\(\)]*(\d{2})/,
      /8[\s\-\(\)]*(\d{3})[\s\-\(\)]*(\d{3})[\s\-\(\)]*(\d{2})[\s\-\(\)]*(\d{2})/,
      /(?:\+7|8)[\s\-\(\)]*(\d{10})/
    ]
    
    phone_patterns.each do |pattern|
      if match = contact.body.match(pattern)
        # Format the phone number
        if match.captures.length >= 4
          return "+7 (#{match[1]}) #{match[2]}-#{match[3]}-#{match[4]}"
        else
          return "+7 #{match[1]}"
        end
      end
    end
    
    nil
  end

  # Generate LocalBusiness address data for AggregateRating schema
  def localbusiness_address_data
    return nil unless @subdomain
    
    city = @subdomain.city || "Мурманск"
    street_address = @subdomain.ya_address.present? ? @subdomain.ya_address : "ул. Ростинская, д. 9А"
    
    address_data = {
      street_address: street_address,
      locality: city,
      country: extract_country_from_suffix(@subdomain.suffix) || "Россия"
    }
    
    # Add region if available from suffix
    if @subdomain.suffix.present?
      region = extract_region_from_suffix(@subdomain.suffix)
      address_data[:region] = region if region
    end
    
    # Add postal code based on city (basic mapping)
    postal_code_map = {
      "Москва" => "101000",
      "Санкт-Петербург" => "190000", 
      "Мурманск" => "183017",
      "Новосибирск" => "630000",
      "Екатеринбург" => "620000",
      "Красноярск" => "660000"
    }
    
    address_data[:postal_code] = postal_code_map[city] || "000000"
    
    address_data
  end

  # Generates comprehensive FAQPage Schema.org JSON-LD markup
  # Uses dynamic data from subdomain and existing FAQ structure
  def generate_faq_schema(faq_data = nil)
    # Use passed data or generate default FAQ data
    faq_data ||= get_default_faq_data
    
    return "" if blank?(faq_data) || blank?(faq_data[:questions])
    
    # Generate main entity array for all questions
    main_entity = faq_data[:questions].map do |q|
      {
        "@type" => "Question",
        "name" => q[:question],
        "acceptedAnswer" => {
          "@type" => "Answer",
          "text" => q[:answer]
        }
      }
    end
    
    schema_data = {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => main_entity
    }
    
    # Generate JSON-LD script tag
    content_tag :script, JSON.pretty_generate(schema_data).html_safe, 
                type: "application/ld+json"
  end
  
  # Generates default FAQ data with dynamic city information
  def get_default_faq_data
    city = @subdomain&.city || "Мурманске"
    city_datel = @subdomain&.morph_datel || "Мурманску"
    city_predl = @subdomain&.morph_predl || "Мурманске"
    
    {
      title: "Ответы на часто задаваемые вопросы о доставке цветов в #{city_predl}",
      description: "В этом разделе мы собираем и дополняем ответы на ваши вопросы, возникающие в процессе использования нашего сервиса по доставке цветов в #{city_predl}.",
      questions: [
        {
          question: "Куда можно заказать цветы с доставкой по #{city_datel}?",
          answer: "Наш сервис по продаже цветов работает по всей территории России. Если вашего населенного пункта не оказалось в списке, звоните, и мы решим, как отвезти букет в нужный город по вашему заказу."
        },
        {
          question: "Какие сроки и стоимость доставки цветов в магазине?",
          answer: "Минимальные сроки доставки в течение 2х часов. Возможно смещение по времени в большую или меньшую сторону в зависимости от многих факторов в доставке. Уточняйте у оператора. Ознакомиться с действующими тарифами Вы можете <a href='#{get_dynamic_url('/page/dostavka/')}' rel='nofollow'>здесь</a>."
        },
        {
          question: "Как получить цветы к точному времени по своему заказу?",
          answer: "Напишите время в примечаниях, и курьер приедет к точному времени ±15 минут."
        },
        {
          question: "Как узнать, где мой букет?",
          answer: "Отследить доставку Вы можете по телефону 8 (800) 250-64-70 (бесплатно по России)."
        },
        {
          question: "Можно ли доставить цветы за город?",
          answer: "Наши агенты могут отвезти цветы в область. Стоимость составляет 20 рублей за километр от города."
        },
        {
          question: "Возможна ли оплата картой на сайте?",
          answer: "Да, Вы можете оплатить букет на сайте без комиссии при оформлении в корзине. Ваши личные данные будут защищены политикой конфиденциальности, мы не сохраняем обработку персональных данных."
        },
        {
          question: "Какие гарантии, что цветы привезут в #{city}?",
          answer: "Наша компания давно работает на рынке. За это время в интернете скопилось много положительных отзывов, с которыми можно ознакомиться. Мы дорожим нашей репутацией."
        },
        {
          question: "Как доставить цветы анонимно в #{city}?",
          answer: "Достаточно не подписывать открытку. Мы не говорим получателю, от кого цветы."
        },
        {
          question: "Где увидеть фото букета?",
          answer: "Флористы бесплатно сфотографируют букет и отправят Вам фото. Можем сфотографировать получателя с букетом при его согласии."
        },
        {
          question: "Как подписать открытку к букету, который доставят в #{city}?",
          answer: "Вы можете написать пожелание в открытку и подписаться совершенно бесплатно при оформлении в корзине."
        },
        {
          question: "Как доставить букет, не зная адреса?",
          answer: "Вам нужно оставить номер телефона получателя, и мы уточним адрес и время, и нам стоит доверять, ведь у нас заказали уже тысячи букетов."
        }
      ]
    }
  end
  
  # Helper to generate dynamic URLs using CURRENT_DOMAIN
  # Avoids using murmansk subdomain which redirects to root
  def get_dynamic_url(path = '/')
    return path if blank?(path) || path.start_with?('http')
    
    # Use CURRENT_DOMAIN constant which is always available
    base_domain = defined?(CURRENT_DOMAIN) ? CURRENT_DOMAIN : "rozarioflowers.ru"
    
    # Handle murmansk special case - it redirects to root domain
    if @subdomain&.url == 'murmansk'
      protocol = request.ssl? ? "https://" : "http://"
      "#{protocol}#{base_domain}#{path}"
    else
      # For other cities, use subdomain URL
      subdomain_prefix = @subdomain&.url || ""
      subdomain_prefix = subdomain_prefix.empty? ? "" : "#{subdomain_prefix}."
      protocol = request.ssl? ? "https://" : "http://"
      "#{protocol}#{subdomain_prefix}#{base_domain}#{path}"
    end
  end

  # Generate comprehensive reviews Schema.org JSON-LD markup
  def generate_reviews_schema(comments = nil)
    # Use passed comments or get default published comments
    comments ||= Comment.published.order('created_at desc')
    
    return "" if blank?(comments) || comments.empty?
    
    # Get organization name and URL dynamically
    org_name = "Розарио.Цветы"
    current_domain = CURRENT_DOMAIN
    org_url = @subdomain.url != 'murmansk' ? "https://#{@subdomain.url}.#{current_domain}" : "https://#{current_domain}"
    
    # Calculate aggregate rating
    total_reviews = comments.size
    return "" if total_reviews == 0
    
    total_rating = comments.sum(&:rating)
    average_rating = (total_rating.to_f / total_reviews).round(1)
    
    # Generate reviews array (limit to first 10 for performance)
    reviews_array = comments.first(10).map do |comment|
      review_date = comment.date.present? ? comment.date : comment.created_at
      {
        "@type" => "Review",
        "itemReviewed" => {
          "@type" => "Organization",
          "name" => org_name
        },
        "author" => comment.name,
        "datePublished" => review_date.strftime("%Y-%m-%d"),
        "description" => comment.body,
        "reviewRating" => {
          "@type" => "Rating",
          "bestRating" => "5",
          "ratingValue" => comment.rating.to_s,
          "worstRating" => "1"
        }
      }
    end
    
    # Build the complete schema
    schema_data = {
      "@context" => "http://schema.org",
      "@type" => "Organization",
      "name" => org_name,
      "url" => org_url,
      "aggregateRating" => {
        "@type" => "AggregateRating",
        "itemReviewed" => {
          "@type" => "Organization",
          "name" => org_name
        },
        "ratingValue" => average_rating.to_s,
        "reviewCount" => total_reviews.to_s
      },
      "review" => reviews_array
    }
    
    content_tag(:script, 
                JSON.pretty_generate(schema_data).html_safe, 
                type: "application/ld+json")
  end
  
  # Generate reviews schema for sidebar (limited to 3 reviews)
  def generate_sidebar_reviews_schema(comments = nil)
    # Get only first 3 published comments for sidebar
    comments ||= Comment.published.order('created_at desc').limit(3)
    generate_reviews_schema(comments)
  end

  # Extract video elements from HTML content and generate VideoObject schemas
  def generate_video_schemas_from_content(html_content, page_title = nil, page_date = nil)
    return "" if blank?(html_content)
    
    begin
      # Parse HTML content to find video elements
      videos = extract_videos_from_html(html_content)
      return "" if videos.empty?
      
      # Generate schema for each video
      schemas = videos.map.with_index do |video_data, index|
        generate_single_video_schema(
          video_data,
          page_title,
          page_date,
          index + 1
        )
      end
      
      schemas.compact.join("\n")
    rescue => e
      # Log error but don't break the page
      ""
    end
  end
  
  private
  
  # Extract video data from HTML content
  def extract_videos_from_html(html_content)
    videos = []
    
    # Match video tags with various attributes
    video_regex = /<video[^>]*>(.*?)<\/video>/mi
    
    html_content.scan(video_regex) do |match|
      full_video_tag = $&  # Get the full matched video tag
      
      # Extract video attributes
      video_data = {
        poster: extract_attribute(full_video_tag, 'poster'),
        controls: full_video_tag.include?('controls')
      }
      
      # Extract source elements
      source_regex = /<source[^>]*src=["']([^"']+)["'][^>]*type=["']([^"']+)["'][^>]*\/?>/i
      sources = []
      
      match[0].scan(source_regex) do |src, type|
        sources << { src: src, type: type }
      end
      
      # Also try to extract from video tag src attribute directly
      if sources.empty?
        video_src = extract_attribute(full_video_tag, 'src')
        if present?(video_src)
          # Determine type from file extension
          type = case video_src.downcase
          when /\.mp4$/; 'video/mp4'
          when /\.webm$/; 'video/webm'
          when /\.ogg$/; 'video/ogg'
          when /\.avi$/; 'video/avi'
          when /\.mov$/; 'video/mov'
          else; 'video/mp4'  # Default
          end
          sources << { src: video_src, type: type }
        end
      end
      
      if !sources.empty?
        video_data[:sources] = sources
        videos << video_data
      end
    end
    
    videos
  end
  
  # Extract attribute value from HTML tag
  def extract_attribute(html_tag, attribute)
    # Match both single and double quotes
    match = html_tag.match(/#{attribute}=["']([^"']*)["']/i)
    match ? match[1] : nil
  end
  
  # Generate single VideoObject schema
  def generate_single_video_schema(video_data, page_title, page_date, video_index = 1)
    return "" unless video_data && video_data[:sources] && !video_data[:sources].empty?
    
    primary_source = video_data[:sources].first
    content_url = primary_source[:src]
    
    # Ensure URL is absolute
    if content_url && !content_url.start_with?('http')
      current_domain = CURRENT_DOMAIN
      base_url = @subdomain.url != 'murmansk' ? "https://#{@subdomain.url}.#{current_domain}" : "https://#{current_domain}"
      content_url = content_url.start_with?('/') ? "#{base_url}#{content_url}" : "#{base_url}/#{content_url}"
    end
    
    # Generate video title
    video_title = if present?(page_title)
      video_index == 1 ? page_title : "#{page_title} - Видео #{video_index}"
    else
      "Видео #{video_index}"
    end
    
    # Generate description
    video_description = if present?(page_title)
      "Видео к статье: #{page_title}"
    else
      "Видео от Rozario Flowers"
    end
    
    # Build schema data
    schema_data = {
      "@context" => "https://schema.org",
      "@type" => "VideoObject",
      "name" => video_title,
      "description" => video_description,
      "contentUrl" => content_url
    }
    
    # Add thumbnail if poster is present
    if present?(video_data[:poster])
      thumbnail_url = video_data[:poster]
      # Ensure thumbnail URL is absolute
      if !thumbnail_url.start_with?('http')
        current_domain = CURRENT_DOMAIN
        base_url = @subdomain.url != 'murmansk' ? "https://#{@subdomain.url}.#{current_domain}" : "https://#{current_domain}"
        thumbnail_url = thumbnail_url.start_with?('/') ? "#{base_url}#{thumbnail_url}" : "#{base_url}/#{thumbnail_url}"
      end
      schema_data["thumbnailUrl"] = thumbnail_url
    end
    
    # Add upload date if available
    if page_date
      begin
        formatted_date = page_date.respond_to?(:strftime) ? page_date.strftime("%Y-%m-%d") : page_date.to_s
        schema_data["uploadDate"] = formatted_date
      rescue
        # Skip date if there's an error
      end
    end
    
    # Add duration if we can extract it (placeholder for future enhancement)
    # schema_data["duration"] = "PT0M0S"  # ISO 8601 duration format
    
    # Add publisher
    schema_data["publisher"] = {
      "@type" => "Organization",
      "name" => "Rozario Flowers"
    }
    
    # Generate script tag
    content_tag(:script, 
                JSON.pretty_generate(schema_data).html_safe, 
                type: "application/ld+json")
  end
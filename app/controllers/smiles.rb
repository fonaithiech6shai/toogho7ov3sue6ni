# encoding: utf-8
Rozario::App.controllers :smiles do
  get('/gettt/:page/?') do
    puts "get ('/smiles/gettt/:page/?') app.rb"
    # offset = params[:page].to_i * 10 - 10
    @offset = params[:page].to_i * 12 - 12
    @posts = Smile.published.order('created_at DESC').offset(@offset).limit(12)
    @lastget = @offset >= Smile.published.count - 12
    erb :'smiles/get'
  end

  # отобразить форму для создания нового поста
  get ('/create/?') do
    erb :'smiles/create'
  end

  # взять параметры из формы и сохранить пост

  get ('/?') do
    @tt = false
    @postsss = Smile.published.order('created_at DESC').limit(12)
    @lastget = @postsss.size < 12
    get_seo_data('smiles_page', nil, true)
    erb :'smiles/index', layout: :'layouts/erbhf'
  end

  get ('/product/:id/?') do
    @pid = params[:id]
    @tt = true
    @postsss = Smile.published
    @result = []
    @postsss.each do |smile|
      order = JSON.parse(smile.json_order)
      order.each do |prdct|
        @result[@result.size] = smile if prdct[1]['id'] == @pid
      end
    end

    @lastget = @result.size < 12

    @postsss = @result
    get_seo_data('smiles_page', nil, true)
    erb :'smiles/index', layout: :'layouts/erbhf'
  end

  get ('/product/:pid/:sid/?') do
    @dsc = DscntClass.new.some_method
    @pid = params[:pid]
    @id = params[:sid]
    @postsss = Smile.published
    @result = []
    @postsss.each do |smile|
      order = JSON.parse(smile.json_order)
      order.each do |prdct|
        @result[@result.size] = smile if prdct[1]['id'] == params[:pid]
      end
    end
    @postsss = @result
    i = 0; for item in @postsss
             if item.id == @id.to_i
               if !@postsss[i + 1]
                 @p_prev = @postsss[i - 1].id
                 @p_next = @postsss[0].id
               else
                 @p_prev = @postsss[i - 1].id
                 @p_next = @postsss[i + 1].id
               end
               break
             end
             i += 1
    end

    # Load SEO data and generate custom title for smiles pages
    @smile = Smile.published.find_by_id(@id)
    @post = @smile  # For template compatibility
    
    # Return 404 if smile not found or unpublished
    halt 404 unless @smile
    
    get_seo_data('smiles', @smile.seo_id) if @smile
    
    # Set canonical URL for smiles pages
    if @smile && @smile.slug
      @canonical_url = "https://#{request.env['HTTP_HOST']}/smiles/#{@smile.slug}"
      @is_smile_page = true
    end
    
    # Apply fallback values only if fields are empty
    custom_title = generate_smile_title(@id)
    @seo[:title] = custom_title if custom_title && (@seo[:title].nil? || @seo[:title].strip.empty?)
    
    # Generate custom descriptions only if fields are empty
    @seo[:description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:description].nil? || @seo[:description].strip.empty?
    @seo[:og_description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:og_description].nil? || @seo[:og_description].strip.empty?
    @seo[:twitter_description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:twitter_description].nil? || @seo[:twitter_description].strip.empty?

    erb :'smiles/show', layout: :'layouts/erbhf'
  end

  get ('/gettttt/:page/?') do
    @product = Product.find_by_id(params[:id])
    @postsss = Smile.published
    @result = []
    @offset = params[:page].to_i * 12 - 12
    i = 0
    @postsss.each do |smile|
      i += 1
      order = JSON.parse(smile.json_order)
      order.each do |prdct|
        if prdct[1]['id'] == params[:id] && i < @offset
          @result[@result.size] = smile
        end
      end
    end

    @postsss = @result

    @lastget = @result.count >= 12

    erb :'smiles/get'
  end

  get ('/:slug/?') do
    if request.session[:mdata].nil?
      current_date = '2019-03-09'
      session[:mdata] = '2019-03-09'
    else
      current_date = request.session[:mdata]
    end
    date_begin = Date.new(2019, 3, 23).to_s
    date_end = Date.new(2019, 3, 25).to_s
    value = ''
    if (current_date.to_s >= date_begin) && (current_date.to_s <= date_end)
      value = 'true'
      ProductComplect.check(value)
    else
      value = 'false'
      ProductComplect.check(value)
      # @change = ProductComplect.new()
      # @change.check(value)
    end
    @dsc = DscntClass.new.some_method
    smile = Smile.published.find_by_slug(params[:slug])
    @id = smile.id if smile.present?
    
    # Fallback для старых ссылок, но только среди опубликованных
    if @id.nil?
      fallback_smile = Smile.published.find_by_id(params[:slug])
      @id = fallback_smile.id if fallback_smile.present?
    end
    
    # Return 404 if no published smile found
    halt 404 unless @id
    @posts = Smile.published.order('created_at DESC')
    i = 0
    for item in @posts
      if item.id == @id.to_i
        if !@posts[i + 1]
          @p_prev = @posts[i - 1].id
          @p_next = @posts[0].id
        else
          @p_prev = @posts[i - 1].id
          @p_next = @posts[i + 1].id
        end
        break
      end
      i += 1
    end
    @smile = Smile.published.find_by_id(@id)
    @post = @smile  # For template compatibility
    
    # Return 404 if smile not found or unpublished
    halt 404 unless @smile
    
    "https://" + request.env['HTTP_HOST'] +  '/smiles/' + @smile.slug if @smile && @smile.slug
    get_seo_data('smiles', @smile.seo_id) if @smile
    
    # Set canonical URL for smiles pages
    if @smile && @smile.slug
      @canonical_url = "https://#{request.env['HTTP_HOST']}/smiles/#{@smile.slug}"
      @is_smile_page = true
    end
    
    # Apply fallback values only if fields are empty
    custom_title = generate_smile_title(@id)
    if custom_title
      @seo[:title] = custom_title if @seo[:title].nil? || @seo[:title].strip.empty?
      @seo[:og_title] = custom_title if @seo[:og_title].nil? || @seo[:og_title].strip.empty?
      @seo[:twitter_title] = custom_title if @seo[:twitter_title].nil? || @seo[:twitter_title].strip.empty?
    end
    
    # Generate custom descriptions only if fields are empty
    @seo[:description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:description].nil? || @seo[:description].strip.empty?
    @seo[:og_description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:og_description].nil? || @seo[:og_description].strip.empty?
    @seo[:twitter_description] = clean_seo_description(generate_smile_description(@id, nil)) if @seo[:twitter_description].nil? || @seo[:twitter_description].strip.empty?

    erb :'smiles/show', layout: :'layouts/erbhf'
  end
end

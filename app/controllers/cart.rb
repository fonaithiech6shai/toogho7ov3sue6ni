# encoding: utf-8
#234244434
Rozario::App.controllers :cart do

  get :test do
    content_type :json
    return @subdomain.to_json
  end

  get :index do
    puts "get :index do cart.rb"
    puts request.session[:mdata]
    @key = 0
    if request.session[:mdata].nil? 
      current_date = Date.current
      session[:mdata] = Date.current
    else
      current_date = request.session[:mdata]
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
    end
    if defined? cookies[:overcookie]
      puts 'cookie yes!!'
      puts 'CCCCCCCCCCOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOKKKKKKKKKKK', session[:mdata], 'CCCCCCCCCCOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOKKKKKKKKKKK'
      @user_name = cookies[:overcookie].to_s
      puts @user_name
    else
      puts 'session yes!!'
      puts 'CCCCCCCCCCOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOKKKKKKKKKKK', session[:mdata], 'CCCCCCCCCCOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOKKKKKKKKKKK'
      @user_name = session[:mdata].to_s
      puts @user_name
    end
    puts 'hey'
    puts request.session[:mdata]
    session[:cart] = session[:cart].nil? ? nil : session[:cart].reject { |x| !Product.find(x['id']).check_availability(@subdomain_pool) }

    @cart = session[:cart]
    #@cross_cats = @subdomain && @subdomain.enable_categories ? Category.where(id: @subdomain.category_ids.to_s.split(','), :show_in_crosssell => true) : Category.where(:show_in_crosssell => true)
    tmp =  Categorygroup.where(id: @subdomain_pool.crosssel_categorygroup_id).pluck(:id)
    @cross_cats = @subdomain_pool && @subdomain_pool.enable_categories ? Category.where(id: CategoriesCategorygroup.where(categorygroup_id: tmp).pluck(:category_id)) : Category.where(:show_in_crosssell => true)
    @slideshow =  @subdomain_pool && @subdomain_pool.enable_slideshows ? Slideshow.where(id: @subdomain_pool.slideshow_cart_id).first : Slideshow.where(:cart => true).first
    @slideshow = Slideshow.where(id: @subdomain.slideshow_cart_id).first unless !@subdomain.enable_slideshows
    #@slideshow = @subdomain && @subdomain.enable_slideshows ? Slideshow.where(id: @subdomain.slideshow_cart_id).first : Slideshow.where(:cart => true).first
    if @subdomain.url == 'murmansk'; @payment_methods = PaymentMethod.all
    else;                            @payment_methods = PaymentMethodSubdomains.all; end
    render 'cart/check'
  end

  get :show do
    puts "get :show cart.rb"
    @cart = session[:cart]
    #@cross_cats = @subdomain && @subdomain.enable_categories ? Category.where(id: @subdomain.category_ids.to_s.split(','), :show_in_crosssell => true) : Category.where(:show_in_crosssell => true)
    tmp =  Categorygroup.where(id: @subdomain_pool.crosssel_categorygroup_id).pluck(:id)
    @cross_cats = @subdomain_pool && @subdomain_pool.enable_categories ? Category.where(id: CategoriesCategorygroup.where(categorygroup_id: tmp).pluck(:category_id)) : Category.where(:show_in_crosssell => true)
    @slideshow =  @subdomain_pool && @subdomain_pool.enable_slideshows ? Slideshow.where(id: @subdomain_pool.slideshow_cart_id).first : Slideshow.where(:cart => true).first
    @slideshow = Slideshow.where(id: @subdomain.slideshow_cart_id).first unless !@subdomain.enable_slideshows
    #@slideshow = @subdomain && @subdomain.enable_slideshows ? Slideshow.where(id: @subdomain.slideshow_cart_id).first : Slideshow.where(cart: true)
    render 'cart/show', :layout => false
  end

  get :newcart do
    puts "get :newcart cart.rb"
    render 'cart/newcart'
  end

  get :stat do
    puts "get :stat cart.rb"
    total_q = 0
    unless session[:cart].nil?
      session[:cart].each do |item|
        total_q += item["quantity"].to_i
      end
    end
    content_type :json
    { :total_s => total, :total_q => total_q }.to_json
  end

  get :add, :map => '/cart/add/:id' do
    puts "get :add, :map => /cart/add/:id cart.rb"
    type = params[:type].present? ? params[:type] : "standard"
    curr_item = { "id" => params[:id], "quantity" => params[:quantity], "type" => type }
    if session[:cart].nil?
      cart = Array.new()
    else
      cart = session[:cart]
    end
    incart = false
    cart.each_with_index do |item, index|
      if item["id"] == curr_item["id"] && (item["type"] == curr_item["type"] || (item["type"].blank? && curr_item["type"] == "standart" ))
        cart[index]["quantity"] = (cart[index]["quantity"].to_i + curr_item["quantity"].to_i).to_s
        incart = true
      end
    end
    if incart
      session[:cart] = cart
    else
      session[:cart] = cart.push(curr_item)
    end
    #redirect(back, :notice => 'Товар добавлен в корзину.')
    redirect back
  end

  get :add, :map => '/add-to-cart/:id' do
    puts "get :add, :map => /add-to-cart/:id cart.rb"
    type = params[:type].present? ? params[:type] : "standard"
    curr_item = { "id" => params[:id], "quantity" => params[:quantity], "type" => type }
    if session[:cart].nil?
      cart = Array.new()
    else
      cart = session[:cart]
    end
    incart = false
    cart.each_with_index do |item, index|
      if item["id"] == curr_item["id"] && (item["type"] == curr_item["type"] || (item["type"].blank? && curr_item["type"] == "standart" ))
        cart[index]["quantity"] = (cart[index]["quantity"].to_i + curr_item["quantity"].to_i).to_s
        incart = true
      end
    end
    if incart
      session[:cart] = cart
    else
      session[:cart] = cart.push(curr_item)
    end
    #redirect(back, :notice => 'Товар добавлен в корзину.')
    
    erb 'SUCCESS!'

  end

  get :del, :with => :id do
    puts "get :del, :with => :id cart.rb"
    type = params[:type].present? ? params[:type] : "standard"
    session[:cart].delete_if {|item| item["id"] == params[:id] && (item["type"].blank? || item["type"] == type)}
    redirect back
  end

  get :clear do
    puts "get :clear cart.rb"
    session[:cart] = nil
    redirect back
  end

  get :refresh do
    puts "get :refresh cart.rb"
  end

  get :precheckout do
    puts "get :precheckout cart.rb"
    if current_account
      render "cart/skipauth", :layout => false
    else
      # Store current checkout page for return after authentication
      set_auth_context('checkout')
      store_location(request.fullpath)
      @session = session
      @user_account = UserAccount.new
      @cart = session[:cart]
      render 'cart/precheckout', :layout => false
      # render "cart/skipauth", :layout => false
    end
  end

  get :checkout do
    puts "get :checkout cart.rb"
    @user_account = UserAccount.new
    @cart = session[:cart]
    if @cart.blank?
      redirect 'cart'
    end
    
    # Store checkout page if user needs to authenticate later
    unless current_account
      set_auth_context('checkout')
      store_location(request.fullpath)
    end
    
    odata = JSON.parse(session[:odata])
    @dt = odata["dt"].to_i
    render 'cart/checkout'
  end

  get :checkouts do
    puts "get :checkouts cart.rb"
    @cart = session[:cart]
    if @cart.blank?
      redirect 'cart'
    end
    odata = JSON.parse(session[:odata])
    @dt = odata["dt"].to_i
    render 'cart/checkouts', :layout => false
  end

  get :payment do
    puts "get :payment cart.rb"
    if session[:odata]
      odata = JSON.parse(session[:odata])
      @total_summ = odata["cart_summ"].to_s
      session[:odata] = nil
      key = Order.last.id
      @orders = Order.new()
      @include_tax = @orders.parse_price(key).to_s
      render 'cart/payment'
    else
      #redirect 'cart'
      render 'cart/payment'
    end
  end

  get :payments do
    puts "get :payments cart.rb"
    @payment = true
    if session[:odata]
      odata = JSON.parse(session[:odata])
      @total_summ = odata["cart_summ"].to_s
      session[:odata] = nil
      key = Order.last.id
      @orders = Order.new()
      @include_tax = @orders.parse_price(key).to_s
      render 'cart/payments', :layout => false
    else
      #render 'cart/tocart'
      render 'cart/payments', :layout => false
    end
  end

  get '/paYH' do 
    puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!', session, params, '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    x = Random.new_seed.to_s
    key = x[0..3].to_s + '-' + x[6..9].to_s + '-' + x[11..14].to_s
    time_now = Time.now.getlocal("+03:00")
    date_to = time_now + 10.days
    promo = Promocode.new(promo_code: key.to_s, data_created: time_now.strftime("%d-%m-%Y %H:%M:%S"), date_to: date_to)
    promo.save
  end

  get :thanks do
    puts "get :thanks cart.rb"
    render 'cart/thanks', :layout => false
  end

  post :getorder, :csrf_protection => false do
    puts "post :getorder, :csrf_protection => false cart.rb"
    session[:odata] = params[:data].to_json
    status 200
  end

  # post :checkout do
  #   puts "post :checkout cart.rb"
  #   @cart = session[:cart]
  #   cart = session[:cart]
  #   odata = JSON.parse(session[:odata])
  #   @dname = odata["d1_name"].to_s.empty? ? odata["d2_name"].to_s : odata["d1_name"].to_s
  #   @dtel = odata["d1_tel"].to_s.empty? ? odata["d2_tel"].to_s : odata["d1_tel"].to_s
  #   p ["ODATA", odata]
  #   p ["PARAMS", params]
  #   @total_summ = odata["cart_summ"].to_f.round(2).to_s
  #   @payment_type_text = ""
  #   @orders = Order.new()
  #   @include_tax = Order.parse_price.to_s

  #   # if @subdomain.url = 'murmansk'; @payment_method = PaymentMethod.where(order: params["payment_type"])
  #   # else;                           @payment_method = PaymentMethodSubdomains.where(order: params["payment_type"].to_i - 10); end
    
  #   case params["payment_type"]
  #     when "1"
  #       @payment_type_text = "Наличными курьеру"
  #     when "2"
  #       @payment_type_text = "Пластиковой картой курьеру"
  #     when "3"
  #       @payment_type_text = "Самостоятельно в цветочном центре"
  #     when "4"
  #       @payment_type_text = "Оплатить на сайте"
  #   end

  #   @tags = tags
  #   @name = params[:name].to_s
  #   @tel = params[:tel].to_s
  #   @email = params[:email].to_s
  #   email = @email
  #   @comment = params[:comment]
  #   @dt_txt = odata["dt_txt"].to_s
  #   @d1_date = odata["d1_date"].to_s
  #   @d2_date = odata["d2_date"].to_s
  #   @city_text = odata["city_text"].to_s
  #   @district_text = odata["district_text"].to_s
  #   @suburb_text = odata["suburb_text"].to_s
  #   @delivery_city = odata["delivery_city"].to_s
  #   @delivery_address = odata["delivery_address"].to_s
  #   @delivery_price = odata["delivery_price"].to_s
  #   @add_card = odata["add_card"].to_i == 1 ? "Да" : "Нет"
  #   @card_text = odata["add_card"].to_i == 1 ? odata["card_text"].to_s : nil
  #   @make_photo = params[:make_photo].to_i == 1 ? "Да" : "Нет"
  #   @ostav = params[:ostav].to_i == 1 ? "Да" : "Нет"
  #   user_date = @d1_date.blank? ? DateTime.parse(@d2_date + " +0400") : DateTime.parse(@d1_date + " +0400")
    
  #   @dcall = odata["dcall"].to_i

  #   if    (@dcall == 1); @surprise = odata["surprise"].to_s; @d2_date_tFr = ''; @d2_date_tTo = '';
  #   elsif (@dcall == 2); @d2_date_tFr = odata["d2_date_tFr"].to_s; @d2_date_tTo = odata["d2_date_tTo"].to_s; end;

  #   if (!params[:tel].empty? && !params[:email].empty?)

  #     invoice_fname = File.join(Padrino.root, "public", "invoices", "order-" + Time.now.to_i.to_s + ".pdf")

  #     # сохраняем заказ в базу
  #     get_eight_digit_id = lambda { |range| x = Random.new.rand(range); return Order.find_by_id(x) ? get_eight_digit_id.call(range) : x }
  #     @eight_digit_id = get_eight_digit_id.call(11..99).to_s + Time.now.getlocal("+03:00").strftime("%d%H%M").to_s
  #     puts '@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id', @eight_digit_id
  #     @order_id = @eight_digit_id
  #     order = Order.new(
  #       eight_digit_id: @eight_digit_id,
  #       total_summ: @total_summ,
  #       userdate: user_date,
  #       delivery_price: @delivery_price,
  #       email: @email,
  #       comment: @comment,
  #       dt_txt: @dt_txt,
  #       d1_date: @d1_date,
  #       city_text: @city_text,
  #       district_text: @district_text,
  #       suburb_text: @suburb_text,
  #       d2_date: @d2_date,
  #       del_city: @delivery_city,
  #       del_address: @delivery_address,
  #       del_price: @delivery_price,
  #       cart: @card_text,
  #       ostav: @ostav,
  #       make_photo: @make_photo,
  #       payment_typetext: @payment_type_text,
  #       dname: @dname,
  #       dtel: @dtel,
  #       dcall: @dcall,
  #       invoice_filename: invoice_fname,
  #       useraccount: current_account,
  #       user_datetime: user_date,
  #       erp_status: 0,
  #       oname: @name
  #     )
  #     order.save
  #     @last_id = Order.pluck(:id).last
  #     session[:order_id] = @order_id

  #     # засунем содержимое корзины в удобный для хранения массив и сохраним его в order_products
  #     frozen_cart = Array.new
  #     cart.each do |item|
  #       puts item
  #       p = Product.find(item["id"])
  #       puts p
  #       product = Product.find_by_id(item["id"])
  #       puts product
  #       type = item["type"].present? ? item["type"] : "standard"
  #       ord = Order_product.new(
  #         id: @last_id,
  #         product_id: p.id,
  #         title: product_item2title(item),
  #         tel: @tel,         
  #         price: product.get_local_complect_price(item, @subdomain, @subdomain_pool, product.categories.first),
  #         quantity: item["quantity"],
  #         typing: type,    
  #         surprise: @surprise,
  #         date_from: @d2_date_tFr,
  #         date_to: @d2_date_tTo)
  #       ord.save
  #     end

  #     # рендерим pdf с инвойсом из html
  #     thread = Thread.new do
  #       order_html = render 'cart/mailorder'
  #       # f = File.new("file.html", 'w')
  #       # f.puts(order_html)
  #       # f.close
  #       order_obj = PDFKit.new(order_html, :page_size => 'Letter', :margin_top => '0', :margin_right => '0', :margin_bottom => '0', :margin_left => '0')
  #       order_pdf = order_obj.to_pdf
  #       invoice_file = order_obj.to_file(invoice_fname)

  #       # отправляем письмо админу
  #       if    odata["dt"].to_i == 1; d_mess = 'Самовывоз: ' + @d1_date;
  #       elsif odata["dt"].to_i == 2;
  #         if    (@dcall == 1); d_mess = 'Доставка: ' + @d2_date;
  #         elsif (@dcall == 2); d_mess = 'Доставка: ' + @d2_date + ', c ' + @d2_date_tFr + ' до ' + @d2_date_tTo;
  #         end;
  #       end;

  #       subj = "Заказ № #{@order_id} на сайте " + @subdomain.url + ".rozarioflowers.ru" + ' | ' + d_mess
  #       if @dname == 'test'; subj = "ТЕСТОВЫЙ заказ № #{@order_id} на сайте " + @subdomain.url + ".rozarioflowers.ru" + ' | ' + d_mess; end;
  #       subj +=
  #       email do
  #         from "Rozario robot <no-reply@rozarioflowers.ru>"
  #         to "a.krit@rozariofl.ru"
  #         #to "kereal@gmail.com"
  #         subject subj
  #         body "Заказ от " + Time.now.getlocal("+09:00").strftime("%d.%m.%Y %H:%M")
  #         add_file :filename => 'order_' + Time.now.getlocal("+04:00").strftime("%d%m%Y-%H%M") + '.pdf', :content => order_pdf
  #         cart.each do |item|
  #           product = Product.find(item["id"])
  #           puts product.image
  #           add_file :filename => product.header + '.jpg', :content => File.read(File.join(Padrino.root, "public", product.thumb_image.to_s))
  #           #if !product.image.blank?
  #           #  req = Net::HTTP.post_form(URI.parse('https://rozarioflowers.ru/api/product'), { 'id' => item["id"] })
  #           #  res = JSON.parse(req.body)
  #           #  res['_complects'].each {|x|
  #           #    if (x['title']==item["type"])
  #           #      f_path = x['image']['image']['url']
  #           #      if f_path.include?('cap1.png'); f_path = product.image.to_s; end;
  #           #      add_file :filename => File.basename(f_path), :content => File.open(File.join(Padrino.root, "public", f_path), 'rb') { |f| f.read }
  #           #    end
  #           #  }
  #           #end
  #         end
  #       end


  #       # отправляем письмецо юзеру
  #       ubody = render 'cart/mailorder2user'
  #       subj = "Ваш заказ № #{@order_id} на сайте rozarioflowers.ru"
  #       email do
  #         content_type :html
  #         from "Rozario <no-reply@rozarioflowers.ru>"
  #         to email
  #         subject subj
  #         body ubody
  #       end
  #     end

  #     session[:cart] = nil
  #     if params[:payment_type] == "4"
  #       redirect 'cart/payment'
  #     else
  #       session[:odata] = nil
  #       redirect 'cart/thanks'
  #     end
  #   else
  #     flash.now[:error] = 'Пожалуйста, укажите номер телефона и адрес эл. почты.'
  #   end

  #   render 'cart/checkout'

  # end

  # post :checkouts do
  #   puts "post :checkouts cart.rb"
  #   params = JSON.parse(request.env["rack.input"].read)
  #   @cart = session[:cart]
  #   cart = session[:cart]

  #   p params
  #   odata = JSON.parse(session[:odata])
  #   @dname = odata["d1_name"].to_s.empty? ? odata["d2_name"].to_s : odata["d1_name"].to_s
  #   @dtel = odata["d1_tel"].to_s.empty? ? odata["d2_tel"].to_s : odata["d1_tel"].to_s
  #   @total_summ = odata["cart_summ"].to_f.round(2).to_s
  #   @payment_type_text = ""

  #   case params["payment_type"]
  #     when "1"
  #       @payment_type_text = "Наличными курьеру"
  #     when "2"
  #       @payment_type_text = "Пластиковой картой курьеру"
  #     when "3"
  #       @payment_type_text = "Самостоятельно в цветочном центре"
  #     when "4"
  #       @payment_type_text = "Оплатить на сайте"
  #   end

  #   # if @subdomain.url = 'murmansk'; @payment_method = PaymentMethod.where(order: params["payment_type"])
  #   # else;                           @payment_method = PaymentMethodSubdomains.where(order: params["payment_type"].to_i - 10); end

  #   @name = params["name"].to_s
  #   @tel = params["tel"].to_s

  #   @email = params["email"].to_s
  #   email = @email
  #   @comment = params["comment"]
  #   @dt_txt = odata["dt_txt"].to_s

  #   @d1_date = odata["d1_date"].to_s
  #   @city_text = odata["city_text"].to_s
    
  #   @district_text = odata["district_text"].to_s
  #   @suburb_text = odata["suburb_text"].to_s
  #   @delivery_city = odata["delivery_city"].to_s
  #   @key = odata["key"].to_s
  #   @delivery_address = odata["delivery_address"].to_s
  #   @deldom = odata["deldom"].to_s
  #   @delkorpus = odata["delkorpus"].to_s
  #   @delkvart = odata["delkvart"].to_s
  #   @delivery_price = odata["delivery_price"].to_s
  #   @d2_date = odata["d2_date"].to_s
  #   @add_card = odata["add_card"].to_i == 1 ? "Да" : "Нет"
  #   @card_text = odata["add_card"].to_i == 1 ? odata["card_text"].to_s : nil
  #   @make_photo = params["make_photo"].to_i == 1 ? "Да" : "Нет"
  #   @ostav = params["ostav"].to_i == 1 ? "Да" : "Нет"
  #   @surprise = odata["surprise"].to_s

  #   d = @city_text.count ','
  #   if d == 2
  #     puts '22222222'
  #     @country = @city_text.scan(/[[А-Яа-яЁё]+]+,+[[\sА-Яа-яЁё.]+]+,+([\sА-Яа-яЁё]+)/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #     @region = @city_text.scan(/[[А-Яа-яЁё]+]+,+([\sА-Яа-яЁё.]+)/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #     @city = @city_text.scan(/([[А-Яа-яЁё]+]+),+[[\sА-Яа-яЁё.]+]+,+[\sА-Яа-яЁё]+/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #   elsif d == 1
  #     puts "1111111111"
  #     @country = @city_text.scan(/[[А-Яа-яЁё]+]+,+([\sА-Яа-яЁё.]+)/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #     @city = @city_text.scan(/([[А-Яа-яЁё\s]+]+),+[\sА-Яа-яЁё.]+/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #   else 
  #     puts "ELSE"
  #     @city = @city_text.scan(/([А-Яа-яЁё]+)/).to_s.gsub('[','').gsub(']','').gsub('"','')
  #   end

  #   if @dt_txt == 'Забрать в магазине (самовывоз)'
  #     @region = 'Мурманская обл'
  #     @district_text = 'Ростинская ул'
  #     @delkorpus = 'a'
  #     @deldom = '9'
  #     @d2_date = @d1_date
  #   else
  #     puts 'Error Delivery Adress'
  #   end

  #   user_date = @d1_date.blank? ? DateTime.parse(@d2_date + " +0400") : DateTime.parse(@d1_date + " +0400")

  #   @dcall = odata["dcall"].to_i

  #   if    (@dcall == 1); @surprise = odata["surprise"].to_s; @d2_date_tFr = ''; @d2_date_tTo = '';
  #   elsif (@dcall == 2); @d2_date_tFr = odata["d2_date_tFr"].to_s; @d2_date_tTo = odata["d2_date_tTo"].to_s; end;

  #   if (!params["tel"].empty? && !params["email"].empty?)
  #     invoice_fname = File.join(Padrino.root, "public", "invoices", "order-" + Time.now.to_i.to_s + ".pdf")
  #     # сохраняем заказ в базу
  #     get_eight_digit_id = lambda { |range| x = Random.new.rand(range); return Order.find_by_id(x) ? get_eight_digit_id.call(range) : x }
  #     @eight_digit_id = get_eight_digit_id.call(11..99).to_s + Time.now.getlocal("+03:00").strftime("%d%H%M").to_s
  #     puts '@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id@eight_digit_id', @eight_digit_id
  #     @order_id = @eight_digit_id
  #     order = Order.new(
  #       eight_digit_id: @eight_digit_id,
  #       otel: @tel,
  #       date_from: @d2_date_tFr,
  #       date_to: @d2_date_tTo,
  #       surprise: @surprise,
  #       total_summ: @total_summ,
  #       userdate: user_date,
  #       delivery_price: @delivery_price,
  #       email: @email,
  #       comment: @comment,
  #       dt_txt: @dt_txt,
  #       d1_date: @d1_date,
  #       city_text: @city_text,
  #       district_text: @district_text,
  #       suburb_text: @suburb_text,
  #       d2_date: @d2_date,
  #       city: @city,
  #       region: @region,
  #       country: @country,
  #       del_address: @delivery_address,
  #       del_price: @delivery_price,
  #       cart: @card_text,
  #       ostav: @ostav,
  #       make_photo: @make_photo,
  #       payment_typetext: @payment_type_text,
  #       dname: @dname,
  #       dtel: @dtel,
  #       dcall: @dcall,
  #       invoice_filename: invoice_fname,
  #       useraccount: current_account,
  #       user_datetime: user_date,
  #       erp_status: 0,
  #       oname: @name,
  #       deldom: @deldom,
  #       delkorpus: @delkorpus,
  #       delkvart: @delkvart
  #     )
  #     order.save
  #     @last_id = Order.pluck(:id).last
  #     session[:order_id] = @order_id

  #     # засунем содержимое корзины в удобный для хранения массив и сохраним его в order_products
  #     frozen_cart = Array.new
  #     cart.each do |item|
  #       puts item
  #       @key = '2260-9174-7298'
  #       p = Product.find(item["id"])
  #       puts p
  #       product = Product.find_by_id(item["id"])
  #       puts product
  #       type = item["type"].present? ? item["type"] : "standard"
  #       ord = Order_product.new(
  #         id: @last_id,   
  #         product_id: p.id,
  #         title: product_item2title(item),    
  #         price: product.get_local_complect_price(item, @subdomain, @subdomain_pool, product.categories.first, @key),
  #         quantity: item["quantity"],
  #         typing: type,    
  #         date_from: @d2_date_tFr,
  #         date_to: @d2_date_tTo)
  #       ord.save
  #     end

  #     thread = Thread.new do
  #       # рендерим pdf с инвойсом из html
  #       order_html = render 'cart/mailorder'
  #       # f = File.new("file.html", 'w')
  #       # f.puts(order_html)
  #       # f.close
  #       order_obj = PDFKit.new(order_html, :page_size => 'Letter', :margin_top => '0', :margin_right => '0', :margin_bottom => '0', :margin_left => '0')
  #       order_pdf = order_obj.to_pdf
  #       invoice_file = order_obj.to_file(invoice_fname)
  #       order_html = render 'cart/mailorder3dost'
  #       order_obj = PDFKit.new(order_html, :page_size => 'Letter', :margin_top => '0', :margin_right => '0', :margin_bottom => '0', :margin_left => '0')
  #       order2_pdf = order_obj.to_pdf
  #       invoice_file = order_obj.to_file(invoice_fname)

  #       # отправляем письмо админу
  #       if    odata["dt"].to_i == 1; d_mess = 'Самовывоз: ' + @d1_date;
  #       elsif odata["dt"].to_i == 2;
  #         if    (@dcall == 1); d_mess = 'Доставка: ' + @d2_date.strftime("%d%m%Y");
  #         elsif (@dcall == 2); d_mess = 'Доставка: ' + @d2_date.strftime("%d%m%Y") + ', c ' + @d2_date_tFr + ' до ' + @d2_date_tTo;
  #         end;
  #       end;
  #       subj = "Заказ № #{@order_id} на сайте " + @subdomain.url + ".rozarioflowers.ru" + ' | ' + d_mess
  #       if @dname == 'test'; subj = "ТЕСТОВЫЙ заказ № #{@order_id} на сайте " + @subdomain.url + ".rozarioflowers.ru" + ' | ' + d_mess; end;
  #       email do
  #         from "Rozario robot <no-reply@rozarioflowers.ru>"
  #         to ENV['ORDER_EMAIL'].to_s
  #         subject subj
  #         body "Заказ от " + Time.now.getlocal("+03:00").strftime("%d.%m.%Y %H:%M")
  #         add_file :filename => 'order_' + Time.now.getlocal("+04:00").strftime("%d%m%Y-%H%M") + '.pdf', :content => order_pdf
  #         add_file :filename => 'orderDostavka_' + Time.now.getlocal("+04:00").strftime("%d%m%Y-%H%M") + '.pdf', :content => order2_pdf
  #         cart.each do |item|
  #           product = Product.find(item["id"])
  #           add_file :filename => product.header + '.jpg', :content => File.read(File.join(Padrino.root, "public", product.image.to_s))
  #           #if !product.image.blank?
  #           #  req = Net::HTTP.post_form(URI.parse('https://rozarioflowers.ru/api/product'), { 'id' => item["id"] })
  #           #  res = JSON.parse(req.body)
  #           #  res['_complects'].each {|x|
  #           #    if (x['title']==item["type"])
  #           #      f_path = x['image']['image']['url']
  #           #      if f_path.include?('cap1.png'); f_path = product.image.to_s; end;
  #           #      add_file :filename => File.basename(f_path), :content => File.open(File.join(Padrino.root, "public", f_path), 'rb') { |f| f.read }
  #           #    end
  #           #  }
  #           #end
  #         end
  #       end

  #       # отправляем письмецо юзеру
  #       ubody = render 'cart/mailorder2user'
  #       subj = "Ваш заказ № #{@order_id} на сайте rozarioflowers.ru"
  #       email do
  #         content_type :html
  #         from "Rozario <no-reply@rozarioflowers.ru>"
  #         to email
  #         subject subj
  #         body ubody
  #       end
  #     end

  #     session[:cart] = nil
  #     res = "Ok"
  #     if odata["remember"] == 'true'
  #       today = Date.today
  #       Remember.create(
  #         user_account_id: current_account ? current_account.id : 666,
  #         order_id: @order_id,
  #         order_date: today,
  #         notificate_at: today + 1.year
  #       )
  #     end
  #   else
  #     halt 403
  #     res = "Error"
  #   end

  #   content_type :json
  #   "{'Result': #{res}}".to_json
  # end

  get 'form-profile' do
    puts "get form-profile do cart.rb"
    @cart = session[:cart]
    render 'cart/form-profile', :layout => false
  end

  get 'form' do
    puts "get form do cart.rb"
    render 'cart/form', :layout => false
  end

  get ('/testing') do  
    s = Product.select([:id, :slug])
    l = ''
    k =''
    j = ''
    for x in s 
      o = x['id'].to_json
      b = x['slug'].to_json
      for i in o.split('')
          if i == "1"
            i = 'a'
          elsif i == "2"
            i = 'b'
          elsif i == "3"
            i = 'c'
          elsif i == "4"
            i = 'd'
          elsif i == "5"
            i = 'e'
          elsif i == "6"
            i = 'f'
          elsif i == "7"
            i = 'g'
          elsif i == "8"
            i = 'h'
          elsif i == "9"
            i = 'i'
          elsif i == "0"
            i = 'j'
          else
            puts 'hh'
          end
          l.concat(i)
      end
      u = b + '-' + i
      puts u
      #
      #
      #
      #
      #
      #
      #
      #
      #
      #
#
    end
  end

  post ('/testing') do  

    id = params[:LMI_SYS_PAYMENT_ID]
    sum = params[:LMI_PAID_AMOUNT]
    currency = params[:LMI_PAID_CURRENCY]
    date = params[:LMI_SYS_PAYMENT_DATE]

    email do
      content_type :html
      from 'Rozario robot <no-reply@rozarioflowers.ru>'
      to 'l.golubev@rozarioflowers.ru'
      subject 'Оплата заказа ' + id
      body 'Заказ ' + id + ' оплачен ' +  date + '. Cумма ' + sum + ' ' + currency
    end     
    puts 'PAAAAAAAAAARAAAAAAAAAAAAAAMMMMMMMSSSSSSSS', params.to_s, 'PAAAAAAAAAARAAAAAAAAAAAAAAMMMMMMMSSSSSSSS'
    return 'PAAAAAAAAAARAAAAAAAAAAAAAAMMMMMMMSSSSSSSS', params.to_s, 'PAAAAAAAAAARAAAAAAAAAAAAAAMMMMMMMSSSSSSSS'
  end
  
end


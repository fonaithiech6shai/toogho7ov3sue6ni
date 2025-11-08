# encoding: utf-8
Rozario::App.controllers :orders, map: 'api/v1/orders' do

  get :test do
    content_type :json
    return @subdomain.to_json
  end

  get 'complects' do

    res = [[]]
    if params[:product_id].present?
      JSON.parse(params[:product_id].to_json).each do |key, val|
        complect = Product.find(val).complects
        compl = []
        complect.each.with_index do |r, index|
          compl[index] = r[:title]
        end
        res[key.to_i] = compl
      end
    end
    return res.to_json
  end

  post :create do

    email_for_orders = ENV['ORDER_EMAIL'].to_s
    if request.env['HTTP_DATA_TESTING'] == 'true' || params.key?("test_mode")
      email_for_orders = ENV['ADMIN_EMAIL'].to_s
    end

    params = JSON.parse(request.body.read)
    @cart = params['cart_order']
    cart = params['cart_order']
    odata = params['order_data']

    @dname = odata['d1_name'].to_s.empty? ? odata['d2_name'].to_s : odata['d1_name'].to_s
    @dtel = odata['d1_tel'].to_s.empty? ? odata['d2_tel'].to_s : odata['d1_tel'].to_s
    if @dname.downcase == ENV['TESTER_NAME'].downcase; email_for_orders = ENV['ORDER_EMAIL'].to_s; end

    if(Subdomain.find(params['subdomain']).id == 4472)
      @d_price = odata['d_price'] || 0
    else
      @d_price = Subdomain.find(params['subdomain']).price || 0
    end

    total_summ = 0
    cart.each do |item|
      total_summ += item['quantity'].to_i * item['clean_price'].to_i
    end
    @total_summ = total_summ.to_f.round(2).to_i + @d_price.to_i
    @payment_type_text = 'Оплатить на сайте'

    if @subdomain.url == 'murmansk'; @payment_type_text = PaymentMethod.where(order: odata['o_payment']).first.name
    else;                            @payment_type_text = PaymentMethod.where(order: odata['o_payment'].to_i - 10).first.name; end # crutch offset
    # case odata['o_payment']
    #   when '1'; @payment_type_text = 'Наличными курьеру'
    #   when '2'; @payment_type_text = 'Пластиковой картой курьеру'
    #   when '3'; @payment_type_text = 'Самостоятельно в цветочном центре'
    #   when '4'; @payment_type_text = 'Оплатить на сайте'
    # end

    @o_name = odata['o_name'].to_s
    @o_tel = odata['o_phone'].to_s

    @email = odata['o_email'].to_s
    email = @email
    @o_comment = odata['o_comment']

    @dt_txt = 'Забрать в магазине (самовывоз)' if odata['deliveryType'] == 1
    @dt_txt = 'Заказать доставку' if odata['deliveryType'] == 2
    if odata['d1_date'].present?
      @d1_date = odata['d1_date'].to_datetime.strftime('%d/%m/%Y, %H:%M').to_s
    end
    if odata['d2_date'].present?
      @d2_date = odata['d2_date'].to_datetime.strftime('%d/%m/%Y').to_s
    end

    @city_text = odata['d_city_text'].to_s
    @district_text = odata['d_street'].to_s
    @suburb_text = odata['d_street'].to_s

    @delivery_city = odata['d_city_text'].to_s
    @delivery_address = odata['d_street'].to_s
    @deldom = odata['d_house'].to_s
    @delkorpus = odata['d_block'].to_s
    @delkvart = odata['d_room'].to_s
    @delivery_price = @d_price.to_s
    @add_card = odata['add_card'] ? 'Да' : 'Нет'
    @card_text = odata['add_card'] ? odata['card_text'].to_s : nil
    @make_photo = odata['o_question1'].to_i == 1 ? 'Да' : 'Нет'
    @ostav = odata['o_question2'].to_i == 1 ? 'Да' : 'Нет'
    @surprise = odata['surprise'].to_s

    @d2_date_tFr = odata['d2_time_from'].to_s
    @d2_date_tTo = odata['d2_time_to'].to_s

    d = @city_text.count ','
    if d == 2
      @country = @city_text.scan(/[[А-Яа-яЁё]+]+,+[[\sА-Яа-яЁё.]+]+,+([\sА-Яа-яЁё]+)/).to_s.delete('[').delete(']').delete('"')
      @region = @city_text.scan(/[[А-Яа-яЁё]+]+,+([\sА-Яа-яЁё.]+)/).to_s.delete('[').delete(']').delete('"')
      @city = @city_text.scan(/([[А-Яа-яЁё]+]+),+[[\sА-Яа-яЁё.]+]+,+[\sА-Яа-яЁё]+/).to_s.delete('[').delete(']').delete('"')
    elsif d == 1
      @country = @city_text.scan(/[[А-Яа-яЁё]+]+,+([\sА-Яа-яЁё.]+)/).to_s.delete('[').delete(']').delete('"')
      @city = @city_text.scan(/([[А-Яа-яЁё\s]+]+),+[\sА-Яа-яЁё.]+/).to_s.delete('[').delete(']').delete('"')
    else
      @city = @city_text.scan(/([А-Яа-яЁё]+)/).to_s.delete('[').delete(']').delete('"')
    end

    if @dt_txt == 'Забрать в магазине (самовывоз)'
      @region = 'Мурманская обл'
      @district_text = 'Ростинская ул'
      @delkorpus = 'a'
      @deldom = '9'
      @d2_date = @d1_date
    else
      puts 'Error Delivery Adress'
    end

    user_date = @d1_date.blank? ? DateTime.parse(@d2_date + ' +0400') : DateTime.parse(@d1_date + ' +0400')

    @dcall = odata['d_call'].to_i

    if    @dcall == 1; @surprise = odata['surprise'].to_s; @d2_date_tFr = ''; @d2_date_tTo = '';
    elsif @dcall == 2; @d2_date_tFr = odata['d2_time_from'].to_s; @d2_date_tTo = odata['d2_time_to'].to_s; end

    if !odata['o_phone'].empty? && !odata['o_email'].empty?

      invoice_fname = File.join(Padrino.root, 'public', 'invoices', 'order-' + Time.now.to_i.to_s + '.pdf')

      # сохраняем заказ в базу

      buff = false
      until buff
        @eight_digit_id = Random.rand(10_000_000...99_999_999)
        buff = true unless Order.where(eight_digit_id: @eight_digit_id).present?
      end
      session[:user_id].present? ? useracc = UserAccount.find(session[:user_id]) : useracc = nil
      @tel = @o_tel
      @name = @o_name
      @order_id = @eight_digit_id
      order = Order.new(
        eight_digit_id: @eight_digit_id,
        otel: @o_tel,
        date_from: @d2_date_tFr,
        date_to: @d2_date_tTo,
        surprise: @surprise,
        total_summ: @total_summ,
        userdate: user_date,
        delivery_price: @delivery_price,
        email: @email,
        comment: @o_comment,
        dt_txt: @dt_txt,
        d1_date: @d1_date,
        city_text: @city_text,
        district_text: @district_text,
        suburb_text: @suburb_text,
        d2_date: @d2_date,
        city: @city,
        region: @region,
        country: @country,
        del_city: @delivery_city,
        del_address: @delivery_address,
        del_price: @delivery_price,
        cart: @card_text,
        ostav: @ostav,
        make_photo: @make_photo,
        payment_typetext: @payment_type_text,
        dname: @dname,
        dtel: @dtel,
        dcall: @dcall,
        invoice_filename: invoice_fname,
        useraccount: useracc,
        user_datetime: user_date,
        erp_status: 0,
        oname: @o_name,
        deldom: @deldom,
        delkorpus: @delkorpus,
        delkvart: @delkvart
      )
      order.save

      @last_id = Order.pluck(:id).last
      session[:order_id] = @order_id

      # засунем содержимое корзины в удобный для хранения массив и сохраним его в order_products
      frozen_cart = []
      cart.each do |item|
        @key = '2260-9174-7298'
        p = Product.find(item['id'])
        product = Product.find_by_id(item['id'])
        type = item['type'].present? ? item['type'] : 'standard'
        ord = Order_product.new(
          order_id: @last_id,
          product_id: p.id,
          title: product_item2title(item),
          price: item['clean_price'],
          quantity: item['quantity'],
          typing: type,
          date_from: @d2_date_tFr,
          date_to: @d2_date_tTo
        )
        ord.save
      end

      # Отправка email синхронно (без Thread для надёжности)
      begin
        puts "[EMAIL] Начинаем отправку писем для заказа #{@order_id}"

        # Генерация PDF
        order_html = render 'cart/mailorder'
        order_obj = PDFKit.new(order_html, :page_size => 'Letter', :margin_top => '0', :margin_right => '0', :margin_bottom => '0', :margin_left => '0')
        order_pdf = order_obj.to_pdf
        invoice_file = order_obj.to_file(invoice_fname)
        order_html = render 'cart/mailorder3dost'
        order_obj = PDFKit.new(order_html, :page_size => 'Letter', :margin_top => '0', :margin_right => '0', :margin_bottom => '0', :margin_left => '0')
        order2_pdf = order_obj.to_pdf
        invoice_file = order_obj.to_file(invoice_fname)

        # отправляем письмо админу
        if odata["deliveryType"].to_i == 1
          d_mess = 'Самовывоз: ' + @d1_date
        elsif odata["deliveryType"].to_i == 2;
          if (@dcall == 1)
            d_mess = 'Доставка: ' + @d2_date
          elsif (@dcall == 2)
            d_mess = 'Доставка: ' + @d2_date + ', c ' + @d2_date_tFr + ' до ' + @d2_date_tTo;
          end
        end

        if email == ENV['ADMIN_EMAIL'].to_s || email.split('@')[1] == ENV['TESTER_EMAIL_SERVER'].to_s
          email_for_orders = ENV['ADMIN_EMAIL'].to_s
        end

        subdomain_url = @subdomain ? @subdomain.url : 'default'
        subj = "Заказ № #{@order_id} на сайте #{subdomain_url}.rozarioflowers.ru" + ' | ' + d_mess
        if @dname == ENV['TESTER_EMAIL'].to_s || @dname == 'test'.downcase; subj = "ТЕСТОВЫЙ заказ № #{@order_id} на сайте " + subdomain_url + ".rozarioflowers.ru" + ' | ' + d_mess; end;
        
        puts "[EMAIL] Отправляем письмо администратору: #{email_for_orders}"
        puts "[EMAIL] Тема: #{subj}"
        email do
          from "Rozario robot <no-reply@rozarioflowers.ru>"
          to email_for_orders
          subject subj
          body "Заказ от " + Time.now.getlocal("+03:00").strftime("%d.%m.%Y %H:%M")
          add_file :filename => 'order_' + Time.now.getlocal("+04:00").strftime("%d%m%Y-%H%M") + '.pdf', :content => order_pdf
          add_file :filename => 'orderDostavka_' + Time.now.getlocal("+04:00").strftime("%d%m%Y-%H%M") + '.pdf', :content => order2_pdf
          cart.each do |item|
            product = Product.find(item["id"])
            if product.image.to_s != ""
              add_file :filename => product.header + '.jpg', :content => File.read(File.join(Padrino.root, "public", product.image.to_s))
            end
          end
        end

        # отправляем письмецо юзеру
        ubody = render 'cart/mailorder2user'
        client_subj = "Ваш заказ № #{@order_id} на сайте rozarioflowers.ru"
        
        puts "[EMAIL] Отправляем письмо клиенту: #{email}"
        puts "[EMAIL] Тема: #{client_subj}"
        email do
          content_type :html
          from "Rozario <no-reply@rozarioflowers.ru>"
          to email
          subject client_subj
          body ubody
        end
        
        puts "[EMAIL] Отправка писем завершена для заказа #{@order_id}"
      rescue => e
        puts "[EMAIL ERROR] Ошибка при отправке писем: #{e.message}"
        puts e.backtrace.join("\n") if e.backtrace
        # Продолжаем выполнение, даже если email не отправился
      end

      session[:cart] = nil
      key = Order.where(eight_digit_id: @order_id).first.id
      order_obj = Order.new
      @include_tax = order_obj.parse_price(key).to_s
      res = { order_id: @order_id, include_tax: @include_tax}
      if odata['remember'] == 'true'
        today = Date.today
        Remember.create(
          user_account_id: session[:user_id].present? ? session[:user_id] : 666,
          order_id: @order_id,
          order_date: today,
          notificate_at: today + 1.year
        )
      end
    else
      halt 403
      res = 'Error'
    end

    content_type :json
    res.to_json
  end
end


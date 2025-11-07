# encoding: utf-8

Rozario::App.controllers :work do
  get :index do # Очищаем БД от мусора, полученного в результате тестирования
    content_type :json
    transaction_conditons = []
    ActiveRecord::Base.transaction do
      orders = Order.where([ "oname IN ('Tester', 'test', 'еуые', 'tsetr', 'ыв32вйвйв цуыва цувцу', '#{ENV['TESTER_NAME'].to_s}')" ])
      payments = Payment.where(order_number: orders.pluck(:eight_digit_id))
      transaction_conditons[0] = [payments.delete_all, orders.delete_all]
    end
    ActiveRecord::Base.transaction do
      orders = Order.where([ "comment IN ('test', 'тест', 'Test', 'Тест', 'TEST')" ])
      payments = Payment.where(order_number: orders.pluck(:eight_digit_id))
      transaction_conditons[1] = [payments.delete_all, orders.delete_all]
    end
    ActiveRecord::Base.transaction do
      orders = Order.where([ "email IN ('#{ENV['ADMIN_EMAIL'].to_s}', '#{ENV['TESTER_EMAIL'].to_s}')" ])
      payments = Payment.where(order_number: orders.pluck(:eight_digit_id))
      transaction_conditons[2] = [payments.delete_all, orders.delete_all]
    end
    # order_products = Order_product.where.not(id: Order.pluck(:id))  # does not work
    # order_products = Order_product.where.not(id: Order.select(:id)) # does not work
    order_products = Order_product.where("NOT EXISTS (SELECT 1 FROM orders WHERE orders.id = order_products.order_id)") # Находим все записи продуктов не связанные с заказами (таблица предназначена для копий записей продуктов с вычисленной ценой под определённый заказ)
    transaction_conditons[3] = order_products.delete_all
    return transaction_conditons.to_json
  end
end


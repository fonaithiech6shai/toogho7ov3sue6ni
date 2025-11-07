# encoding: utf-8
class Order < ActiveRecord::Base
	self.table_name = 'orders'  # Явно указываем имя таблицы
	self.primary_key = 'id'  # Явно указываем первичный ключ
	belongs_to :useraccount, class_name: 'UserAccount'
	belongs_to :status, class_name: 'Status'
	has_many :smiles, foreign_key: 'order_id'
	has_many :order_products, -> { where('1=1') }, foreign_key: 'order_id', class_name: 'Order_product', dependent: :destroy
	
	# Связь с комментариями через eight_digit_id
	has_many :comments, :foreign_key => :order_eight_digit_id, :primary_key => :eight_digit_id
end
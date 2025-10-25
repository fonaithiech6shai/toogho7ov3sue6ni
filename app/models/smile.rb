# encoding: utf-8
require_relative '../helpers/common.rb'

class Smile < ActiveRecord::Base
	include ActiveModel::Validations

  belongs_to :seo, dependent: :destroy
  accepts_nested_attributes_for :seo, allow_destroy: true
  validates_presence_of :title
  validates_uniqueness_of :slug
  
  # Валидация номера заказа (если указан)
  validates_numericality_of :order_eight_digit_id, 
    :only_integer => true, 
    :greater_than => 9_999_999, 
    :less_than => 100_000_000,
    :allow_blank => true
    
  # Проверка существования заказа
  validate :order_exists_if_provided
  
  # Связь с заказом через eight_digit_id
  belongs_to :order, foreign_key: :order_eight_digit_id, primary_key: :eight_digit_id
  
  # Scopes для работы с BIT полем published
  scope :published, -> { where(published: 1) }
  scope :unpublished, -> { where(published: 0) }
  
  # Валидация order_products_base_id (если указан)
  validates_numericality_of :order_products_base_id, 
    :only_integer => true, 
    :greater_than => 0,
    :allow_blank => true

	mount_uploader :images, UploaderSmile

  # Метод для получения имени клиента через order_eight_digit_id
  def customer_name
    return "Покупатель" unless order_eight_digit_id.present?
    
    begin
      # Ищем заказ по номеру заказа (eight_digit_id)
      matching_order = Order.find_by_eight_digit_id(order_eight_digit_id)
      
      return "Покупатель" unless matching_order
      return "Покупатель" unless matching_order.useraccount_id && matching_order.useraccount_id > 0
      
      user_account = UserAccount.find_by_id(matching_order.useraccount_id)
      return "Покупатель" unless user_account
      
      if user_account.surname && user_account.surname.present? && user_account.surname.strip.length > 0
        user_account.surname.strip
      else
        "Покупатель"
      end
      
    rescue => e
      # В случае ошибки возвращаем значение по умолчанию
      "Покупатель"
    end
  end
  
  # Метод для получения имени получателя из поля dname заказа
  def recipient_name
    return "" unless order_eight_digit_id.present?
    
    begin
      # Ищем заказ по номеру заказа (eight_digit_id)
      matching_order = Order.find_by_eight_digit_id(order_eight_digit_id)
      
      return "" unless matching_order
      return "" unless matching_order.dname.present?
      
      matching_order.dname.strip
    rescue => e
      ""
    end
  end
  
  # Метод для получения информации о заказе для админки
  def order_info_for_admin
    return nil unless order_eight_digit_id.present?
    
    begin
      # Находим заказ по eight_digit_id
      order = Order.find_by_eight_digit_id(order_eight_digit_id)
      return nil unless order
      
      # Получаем информацию о пользователе
      user_info = "Гостевой заказ (без регистрации)"
      
      if order.useraccount_id && order.useraccount_id > 0
        user_account = UserAccount.find_by_id(order.useraccount_id)
        if user_account
          name_parts = []
          name_parts << user_account.name if user_account.name.present?
          name_parts << user_account.surname if user_account.surname.present?
          
          if name_parts.any?
            user_info = name_parts.join(' ')
            user_info += " (#{user_account.email})" if user_account.email.present?
          elsif user_account.email.present?
            user_info = user_account.email
          else
            # Если нет имени и email, показываем ID и статус
            user_info = "Зарегистрированный пользователь ID: #{user_account.id}"
          end
        else
          # useraccount_id есть, но пользователь не найден - возможно удален
          user_info = "Пользователь удален (ID: #{order.useraccount_id})"
        end
      end
      
      # Формируем информацию о заказе
      order_date = order.created_at ? order.created_at.strftime('%d.%m.%Y %H:%M') : 'Дата неизвестна'
      
      {
        order: order,
        user_info: user_info,
        order_date: order_date,
        has_user: order.useraccount_id && order.useraccount_id > 0,
        debug_info: {
          useraccount_id: order.useraccount_id,
          user_found: user_account.present?,
          user_has_name: user_account&.name.present?,
          user_has_surname: user_account&.surname.present?,
          user_has_email: user_account&.email.present?
        }
      }
      
    rescue => e
      # В случае ошибки возвращаем nil
      nil
    end
  end
  
  # Метод для получения товара из заказа по order_products_base_id
  def order_product
    return nil unless order_products_base_id.present?
    
    begin
      Order_product.find_by_base_id(order_products_base_id)
    rescue => e
      Rails.logger.error "Error fetching order_product for smile #{id}: #{e.message}" if defined?(Rails)
      nil
    end
  end
  
  # Метод для получения названия товара
  def selected_product_title
    return nil unless order_product
    
    order_product.title || "Товар не найден"
  end
  
  # Метод для получения всех товаров из заказа для отображения на фронтенде
  def order_products_for_display
    return nil unless order_eight_digit_id.present?
    
    begin
      # Находим заказ по eight_digit_id
      order = Order.find_by_eight_digit_id(order_eight_digit_id)
      return nil unless order
      
      # Получаем товары из заказа (в таблице order_products поле id является FK на orders.id)
      cart_items = Order_product.find_by_sql("SELECT * FROM order_products WHERE id = #{order.id}")
      return nil if cart_items.empty?
      
      # Преобразуем в формат, совместимый с json_order
      result = {}
      cart_items.each_with_index do |item, index|
        begin
          product = Product.find_by_id(item.product_id)
          complect = Complect.find_by_title(item.typing) if item.typing
          
          result[index.to_s] = {
            'id' => item.product_id.to_s,
            'complect' => item.typing || 'standard',
            'title' => item.title || (product ? product.header : "Товар не найден"),
            'price' => item.price,
            'quantity' => item.quantity,
            'base_id' => item.respond_to?(:base_id) ? item.base_id : nil,
            'product_exists' => !product.nil?
          }
        rescue => e
          # В случае ошибки создаём fallback запись
          result[index.to_s] = {
            'id' => item.product_id.to_s,
            'complect' => item.typing || 'standard',
            'title' => item.title || "Товар не найден",
            'price' => item.price,
            'quantity' => item.quantity,
            'base_id' => item.respond_to?(:base_id) ? item.base_id : nil,
            'product_exists' => false,
            'error' => e.message
          }
        end
      end
      
      result
      
    rescue => e
      # В случае общей ошибки возвращаем nil - будет использован fallback
      nil
    end
  end
  
  # Метод для получения данных о товарах с fallback
  def products_data
    # Приоритет: данные из реального заказа
    order_data = order_products_for_display
    return order_data if order_data
    
    # Fallback: используем json_order
    begin
      return JSON.parse(json_order) if json_order.present?
    rescue => e
      # Если и json_order неможет быть распарсен
      Rails.logger.error "Error parsing json_order for smile #{id}: #{e.message}" if defined?(Rails)
    end
    
    # Последний fallback - пустой словарь
    {}
  end
  
  # Метод для проверки, что данные загружены из реального заказа
  def using_order_data?
    order_eight_digit_id.present? && order_products_for_display.present?
  end
  
  # Метод для получения связанного комментария (только опубликованные) - оставляем для совместимости
  def related_comment
    related_comments.first
  end
  
  # Новый метод для получения всех связанных комментариев заказа (только опубликованные)
  def related_comments
    return [] unless order_eight_digit_id.present?
    
    begin
      if defined?(Comment)
        # Получаем все комментарии для данного заказа
        comments = Comment.where(order_eight_digit_id: order_eight_digit_id)
        
        # Фильтруем только опубликованные, используя local helper
        comments.select do |comment|
          convert_bit_to_bool(comment.published)
        end.sort_by(&:created_at) # Сортируем по дате создания
      else
        []
      end
    rescue => e
      Rails.logger.error "Error fetching comments for smile #{id}: #{e.message}" if defined?(Rails)
      []
    end
  end
  
  # Метод для проверки, есть ли связанные комментарии для Review схемы
  def has_review_comment?
    related_comments.any? { |comment| comment.body.present? }
  end
  
  # Метод для проверки, есть ли хотя бы один связанный комментарий (для совместимости)
  def has_review_comments?
    related_comments.any?
  end
  
  # Helper метод для проверки статуса публикации
  def published?
    # Используем local helper
    convert_bit_to_bool(published)
  end
  
  private
  
  # Локальный helper для обработки MySQL BIT полей
  def convert_bit_to_bool(value)
    case value
    when nil, false
      false
    when true, 1
      true
    when String
      # MySQL BIT поле может возвращать строку с битовыми данными
      return true if value == '1'
      return true if value.bytes.first == 1 # бинарная единица
      false
    when Integer
      value == 1
    else
      # Любое другое значение - проверяем на "truthy"
      !!value
    end
  rescue => e
    # При ошибке - возвращаем false
    false
  end
  
  # Метод для получения записи order_product по order_products_base_id
  def review_order_product
    return nil unless order_products_base_id.present?
    
    begin
      Order_product.find_by_base_id(order_products_base_id) if defined?(Order_product)
    rescue => e
      Rails.logger.error "Error fetching order_product for smile #{id}: #{e.message}" if defined?(Rails)
      nil
    end
  end
  
  # Метод для получения названия товара для itemReviewed
  def review_item_name
    order_product = review_order_product
    return nil unless order_product
    
    # Приоритет: title из order_products, затем product.header
    if order_product.title.present?
      order_product.title
    elsif order_product.product_id.present?
      begin
        product = Product.find_by_id(order_product.product_id)
        product && product.header.present? ? product.header : nil
      rescue => e
        nil
      end
    else
      nil
    end
  end
  
  # Метод для получения ссылки на изображение товара для itemReviewed
  def review_item_image
    order_product = review_order_product
    return nil unless order_product && order_product.product_id.present?
    
    begin
      product = Product.find_by_id(order_product.product_id)
      return nil unless product
      
      # Используем thumb_image(true) для mobile-версии как в текущей логике
      image_url = product.thumb_image(true)
      image_url.present? ? image_url : nil
    rescue => e
      Rails.logger.error "Error getting product image for smile #{id}: #{e.message}" if defined?(Rails)
      nil
    end
  end
end

  private
  
  def order_exists_if_provided
    return if order_eight_digit_id.blank?
    
    unless Order.exists?(:eight_digit_id => order_eight_digit_id)
      errors.add(:order_eight_digit_id, "Заказ с номером #{order_eight_digit_id} не найден")
    end
  end
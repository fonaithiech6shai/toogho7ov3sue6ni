# encoding: utf-8
class Account < ActiveRecord::Base
  attr_accessor :password, :password_confirmation
  
  # Available admin modules
  AVAILABLE_MODULES = [
    'menus_on_main', 'discounts', 'delivery', 'regions',
    'categorygroups', 'complects', 'pages', 'categories', 
    'products', 'news', 'articles', 'comments', 'contacts',
    'clients', 'accounts', 'seo', 'payment', 'seo_texts',
    'photos', 'albums', 'slides', 'slideshows', 'tags',
    'disabled_dates', 'general_config', 'orders', 'smiles'
  ].freeze
  
  # Role types
  ROLE_TYPES = ['admin', 'manager', 'editor'].freeze

  # Validations
  validates_presence_of     :email, :role
  validates_presence_of     :password,                   :if => :password_required
  validates_presence_of     :password_confirmation,      :if => :password_required
  validates_length_of       :password, :within => 4..40, :if => :password_required
  validates_confirmation_of :password,                   :if => :password_required
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :email,    :case_sensitive => false
  validates_format_of       :email,    :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_inclusion_of    :role,     :in => ROLE_TYPES

  # Callbacks
  before_save :encrypt_password, :if => :password_required

  ##
  # This method is for authentication purpose
  #
  def self.authenticate(email, password)
    account = first(:conditions => { :email => email }) if email.present?
    account && account.has_password?(password) ? account : nil
  end

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end
  
  # Permissions management methods
  def permissions
    return [] if role_permissions.blank?
    begin
      JSON.parse(role_permissions)
    rescue
      []
    end
  end
  
  def permissions=(modules)
    self.role_permissions = modules.is_a?(Array) ? modules.to_json : modules.to_s
  end
  
  def has_permission?(module_name)
    return true if role == 'admin' # Admin has all permissions
    permissions.include?(module_name.to_s)
  end
  
  def add_permission(module_name)
    return false unless AVAILABLE_MODULES.include?(module_name.to_s)
    current_permissions = permissions
    current_permissions << module_name.to_s unless current_permissions.include?(module_name.to_s)
    self.permissions = current_permissions
  end
  
  def remove_permission(module_name)
    current_permissions = permissions
    current_permissions.delete(module_name.to_s)
    self.permissions = current_permissions
  end
  
  def display_name
    [name, surname].compact.join(' ').strip.present? ? [name, surname].compact.join(' ').strip : email
  end

  private
  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password)
  end

  def password_required
    crypted_password.blank? || password.present?
  end
end

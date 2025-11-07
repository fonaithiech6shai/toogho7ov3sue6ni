# encoding: utf-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 88) do

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.string   "surname"
    t.string   "email"
    t.string   "crypted_password"
    t.string   "role"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "albums", :force => true do |t|
    t.string   "title"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "articles", :force => true do |t|
    t.string   "title"
    t.text     "announce"
    t.text     "body"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "categories", :force => true do |t|
    t.string   "title"
    t.text     "announce"
    t.string   "image"
    t.text     "text"
    t.string   "template"
    t.boolean  "show_in_index"
    t.boolean  "show_in_crosssell"
    t.datetime "created_at",                                        :null => false
    t.datetime "updated_at",                                        :null => false
    t.integer  "parent_id",                          :default => 0
    t.integer  "slideshow_id",                                      :null => false
    t.integer  "sort_index"
    t.integer  "discount",             :limit => 1
    t.text     "seo_title"
    t.text     "seo_description"
    t.text     "seo_keywords"
    t.integer  "discount_in_rubles",                 :default => 0
    t.integer  "discount_in_percents",               :default => 0
    t.string   "slug",                 :limit => 70
  end

  create_table "categories_categorygroups", :id => false, :force => true do |t|
    t.integer "category_id",      :null => false
    t.integer "categorygroup_id", :null => false
  end

  create_table "categories_products", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "product_id",  :null => false
  end

  create_table "categories_subdomain_pools", :id => false, :force => true do |t|
    t.integer "category_id",                             :null => false
    t.integer "subdomain_pool_id",                       :null => false
    t.integer "discount_in_rubles",   :default => 0
    t.integer "discount_in_percents", :default => 0
    t.boolean "discount_status",      :default => false
    t.integer "discount_period_id",   :default => 0
  end

  create_table "categories_subdomains", :id => false, :force => true do |t|
    t.integer "category_id",                             :null => false
    t.integer "subdomain_id",                            :null => false
    t.integer "discount_in_rubles",   :default => 0
    t.integer "discount_in_percents", :default => 0
    t.boolean "discount_status",      :default => false
    t.integer "discount_period_id",   :default => 0
  end

  create_table "categorygroups", :force => true do |t|
    t.string "title"
  end

  create_table "categorygroups_subdomain_pools", :id => false, :force => true do |t|
    t.integer "categorygroup_id",  :null => false
    t.integer "subdomain_pool_id", :null => false
  end

  create_table "categorygroups_subdomains", :id => false, :force => true do |t|
    t.integer "categorygroup_id", :null => false
    t.integer "subdomain_id",     :null => false
  end

  create_table "comments", :force => true do |t|
    t.string   "name"
    t.text     "body"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.string   "title"
    t.float    "rating",     :default => 5.0
    t.datetime "date"
  end

  create_table "complects", :force => true do |t|
    t.string   "title"
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.string   "header",     :default => "", :null => false
    t.string   "titlemain",  :default => "", :null => false
  end

  create_table "contacts", :force => true do |t|
    t.string   "name"
    t.text     "body",           :limit => 16777215
    t.text     "about_us_short"
    t.integer  "subdomain_id"
    t.boolean  "enabled"
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "header"
  end

  add_index "contacts", ["subdomain_id"], :name => "index_contacts_on_subdomain_id", :unique => true

  create_table "disabled_dates", :force => true do |t|
    t.string   "name"
    t.datetime "date",                               :null => false
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.boolean  "enabled",         :default => false, :null => false
    t.boolean  "only_delivery",   :default => false, :null => false
    t.boolean  "except_delivery", :default => false, :null => false
  end

  create_table "disabled_dates_subdomains", :id => false, :force => true do |t|
    t.integer "disabled_date_id", :null => false
    t.integer "subdomain_id",     :null => false
  end

  create_table "discount_periods", :force => true do |t|
    t.string  "title"
    t.boolean "eachyear_repeat"
    t.date    "start_date"
    t.date    "end_date"
  end

  create_table "flowers", :force => true do |t|
    t.integer "product_id"
    t.string  "title"
    t.integer "standart_count", :default => 0
    t.integer "small_count",    :default => 0
    t.integer "lux_count",      :default => 0
  end

  create_table "general_configs", :force => true do |t|
    t.string   "name"
    t.string   "value"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "import_users", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "subscribe_code"
    t.boolean  "subscribe",      :default => true
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
  end

  create_table "jobs", :force => true do |t|
    t.string   "object"
    t.string   "method_name"
    t.text     "arguments"
    t.integer  "priority",     :default => 0
    t.string   "return"
    t.string   "exception"
    t.integer  "parent_id"
    t.datetime "created_at"
    t.datetime "run_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "failed_at"
  end

  create_table "leftmenu_cats", :force => true do |t|
    t.integer "leftmenu_id"
    t.integer "category_id"
    t.integer "parentcat_id"
    t.integer "sequence"
    t.string  "slug",         :limit => 70
  end

  create_table "leftmenus", :force => true do |t|
    t.string  "title"
    t.boolean "default"
  end

  create_table "murmanskstreets", :force => true do |t|
    t.string  "name"
    t.integer "price"
    t.boolean "free_delivery"
  end

  create_table "news", :force => true do |t|
    t.string   "title"
    t.text     "announce"
    t.text     "body"
    t.string   "image"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "order_products", :force => true do |t|
    t.integer  "order_id"
    t.integer  "product_id"
    t.string   "title"
    t.integer  "price"
    t.integer  "quantity"
    t.string   "typing"
    t.datetime "date_from"
    t.datetime "date_to"
  end

  add_index "order_products", ["order_id"], :name => "order_id"

  create_table "orders", :force => true do |t|
    t.integer  "eight_digit_id"
    t.integer  "sd"
    t.integer  "useraccount_id",                       :default => 1
    t.integer  "status_id",                            :default => 1
    t.float    "total_summ"
    t.float    "delivery_price"
    t.boolean  "erp_status",                           :default => false
    t.text     "cart",             :limit => 16777215
    t.text     "email",                                                   :null => false
    t.string   "invoice_filename"
    t.datetime "user_datetime"
    t.datetime "created_at",                                              :null => false
    t.datetime "updated_at",                                              :null => false
    t.string   "comment"
    t.string   "dt_txt"
    t.string   "d1_date"
    t.string   "city_text"
    t.string   "district_text"
    t.string   "suburb_text"
    t.string   "d2_date"
    t.string   "del_city"
    t.string   "del_address"
    t.string   "del_price"
    t.string   "price"
    t.string   "quantity"
    t.string   "type"
    t.string   "ostav"
    t.string   "make_photo"
    t.string   "userdate"
    t.string   "payment_typetext"
    t.string   "oname"
    t.string   "dtel"
    t.string   "dcall"
    t.string   "city"
    t.string   "region"
    t.string   "country"
    t.string   "dname"
    t.string   "date_from"
    t.string   "date_to"
    t.string   "surprise"
    t.integer  "deldom"
    t.string   "delkorpus"
    t.integer  "delkvart"
    t.string   "otel"
  end

  create_table "overdateusers", :id => false, :force => true do |t|
    t.boolean  "isnew"
    t.datetime "datenow"
    t.string   "curr_date"
  end

  create_table "overprices", :id => false, :force => true do |t|
    t.string   "date"
    t.datetime "created"
  end

  create_table "overtime_deliveries", :force => true do |t|
    t.string  "title"
    t.integer "price"
    t.boolean "onetime_event"
    t.boolean "eachday_repeat"
    t.boolean "eachyear_repeat"
    t.time    "start_time"
    t.time    "end_time"
    t.date    "start_date"
    t.date    "end_date"
  end

  create_table "pages", :force => true do |t|
    t.string   "uri"
    t.string   "title"
    t.text     "body",        :limit => 2147483647
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.string   "keywords"
    t.string   "description"
    t.string   "header"
  end

  create_table "patterns", :force => true do |t|
    t.string   "slug"
    t.text     "content"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "patterns", ["slug"], :name => "index_patterns_on_slug", :unique => true

  create_table "photos", :force => true do |t|
    t.integer  "album_id"
    t.string   "title"
    t.string   "image"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "product_alt", :id => false, :force => true do |t|
    t.integer "product", :null => false
    t.string  "name",    :null => false
    t.string  "img",     :null => false
    t.integer "price",   :null => false
  end

  add_index "product_alt", ["product"], :name => "product"

  create_table "product_complects", :force => true do |t|
    t.integer  "product_id"
    t.integer  "complect_id"
    t.decimal  "price",       :precision => 10, :scale => 0
    t.string   "image"
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.integer  "price_1990"
    t.integer  "price_2890"
    t.integer  "price_3790"
    t.integer  "over_1990"
    t.integer  "over_2890"
    t.integer  "over_3790"
    t.integer  "over_1290"
  end

  create_table "products", :force => true do |t|
    t.string   "title"
    t.integer  "rating",                     :default => 5,    :null => false
    t.text     "announce"
    t.text     "text"
    t.string   "color"
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.integer  "discount",      :limit => 1
    t.boolean  "trick_price"
    t.integer  "default_image"
    t.integer  "default_price"
    t.integer  "orderp",                     :default => 1000
    t.string   "header"
    t.string   "description"
    t.string   "keywords"
    t.string   "alt"
  end

  add_index "products", ["id"], :name => "id"

  create_table "products_tags", :id => false, :force => true do |t|
    t.integer "product_id"
    t.integer "tag_id"
  end

  create_table "remembers", :force => true do |t|
    t.integer  "user_account_id", :null => false
    t.integer  "order_id"
    t.datetime "notificate_at"
    t.datetime "order_date"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "seo_script_execution_histories", :force => true do |t|
    t.text     "comment"
    t.string   "status"
    t.text     "log"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "seo_scripts", :force => true do |t|
    t.string   "title"
    t.text     "comment"
    t.text     "seo_title"
    t.text     "seo_description"
    t.text     "seo_keywords"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "slides", :force => true do |t|
    t.integer  "slideshow_id"
    t.string   "image"
    t.string   "uri"
    t.text     "text"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.integer  "position",     :default => 20
  end

  create_table "slideshows", :force => true do |t|
    t.string   "title"
    t.boolean  "active"
    t.boolean  "default"
    t.boolean  "cart"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "slideshows", ["id"], :name => "id", :unique => true
  add_index "slideshows", ["id"], :name => "sqlite_autoindex_slideshows_1", :unique => true

  create_table "smiles", :force => true do |t|
    t.string   "title"
    t.text     "date"
    t.text     "json_order"
    t.text     "body"
    t.string   "images",     :default => "",    :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.integer  "rating",     :default => 5
    t.string   "alt"
    t.text     "smile_text"
    t.boolean  "sidebar",    :default => false
  end

  create_table "special_overprices", :force => true do |t|
    t.integer "over_1290"
    t.integer "over_1990"
    t.integer "over_2890"
    t.integer "over_3790"
    t.integer "product_id"
    t.integer "complect_id"
  end

  add_index "special_overprices", ["complect_id"], :name => "complect_id"
  add_index "special_overprices", ["product_id"], :name => "product_id"

  create_table "statuses", :force => true do |t|
    t.string "title"
  end

  create_table "subdomain_pools", :force => true do |t|
    t.string   "name"
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
    t.integer  "slideshow_main_id"
    t.integer  "slideshow_cart_id"
    t.boolean  "enable_slideshows"
    t.integer  "default_category_id"
    t.boolean  "enable_categories"
    t.boolean  "coop_clients"
    t.integer  "crosssel_categorygroup_id"
    t.integer  "leftmenu_id"
    t.integer  "overprsubd_sp",             :default => 0
    t.integer  "ordprod_sp",                :default => 0
    t.integer  "101roze_sp",                :default => 0
  end

  create_table "subdomains", :force => true do |t|
    t.text     "morph_predl"
    t.text     "morph_rodit"
    t.text     "morph_datel"
    t.string   "url"
    t.string   "city"
    t.text     "morph"
    t.string   "title"
    t.string   "keywords"
    t.text     "description"
    t.text     "about"
    t.datetime "created_at",                                                   :null => false
    t.datetime "updated_at",                                                   :null => false
    t.integer  "domain_type"
    t.integer  "price"
    t.string   "suffix"
    t.string   "category_ids"
    t.boolean  "enable_categories"
    t.integer  "slideshow_main_id"
    t.integer  "slideshow_cart_id"
    t.boolean  "enable_slideshows"
    t.string   "category_menu_ids",                       :default => ""
    t.integer  "default_category_id",                     :default => 118
    t.boolean  "coop_clients"
    t.integer  "subdomain_pool_id"
    t.integer  "discount_pool_id"
    t.integer  "leftmenu_id"
    t.integer  "crosssel_categorygroup_id"
    t.boolean  "free_delivery"
    t.integer  "freedelivery_summ",                       :default => 1500
    t.string   "ya_name"
    t.string   "ya_address"
    t.text     "ya_url"
    t.integer  "overprsubd",                              :default => 0
    t.integer  "ordprod",                                 :default => 0
    t.integer  "101roze",                                 :default => 0
    t.string   "timezone",                  :limit => 20, :default => "UTC+3"
  end

  add_index "subdomains", ["url"], :name => "index_subdomains_on_url"

  create_table "subdomains_overtimedeliveries", :id => false, :force => true do |t|
    t.integer "overtime_delivery_id", :null => false
    t.integer "subdomain_id",         :null => false
  end

  create_table "subscribers", :force => true do |t|
    t.string   "name"
    t.text     "email"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "t_temp", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "product_id",  :null => false
  end

  create_table "tag_complects", :force => true do |t|
    t.integer  "product_id"
    t.integer  "complect_id"
    t.integer  "tag_id"
    t.integer  "count"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "tags", :force => true do |t|
    t.string   "title"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "infilters",  :default => false
  end

  create_table "texts", :id => false, :force => true do |t|
    t.integer "category"
    t.text    "text"
    t.text    "h1"
  end

  create_table "user_accounts", :force => true do |t|
    t.string   "name"
    t.string   "surname"
    t.string   "tel"
    t.string   "discount_code"
    t.string   "address"
    t.string   "email"
    t.string   "crypted_password"
    t.string   "role"
    t.string   "recovery_token",   :limit => 32
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
    t.boolean  "subscribe",                      :default => true
    t.string   "subscribe_code"
  end

end

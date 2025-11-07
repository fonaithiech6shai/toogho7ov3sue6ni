# encoding: utf-8
require_relative '../../app/models/order_product'

Rozario::Admin.controllers :orders do

  get :index do
    @title = "Orders"
    @orders = Order.order("created_at DESC").paginate(:page => params[:page], :per_page => 100)
    render 'orders/index'
  end

  get :index, :with => :id do
    @order = Order.find(params[:id])
    render 'orders/show'
  end

  get :edit, :with => :id do
    @title = pat(:edit_title, :model => "order #{params[:id]}")
    @statuses = Status.all
    @order = Order.find(params[:id])
    if @order
      render 'orders/edit'
    else
      flash[:warning] = pat(:create_error, :model => 'order', :id => "#{params[:id]}")
      halt 404
    end
  end

  put :update, :with => :id do
    @title = pat(:update_title, :model => "order #{params[:id]}")
    @order = Order.find(params[:id])
    if @order
      if @order.update_attributes(params[:order])
        flash[:success] = pat(:update_success, :model => 'Order', :id =>  "#{params[:id]}")
        redirect(url(:orders, :index))
      else
        flash.now[:error] = pat(:update_error, :model => 'Order')
        render 'orders/edit'
      end
    else
      flash[:warning] = pat(:update_warning, :model => 'Order', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy, :with => :id do
    @title = "Orders"
    order = Order.find(params[:id])
    if order
      if order.destroy
        flash[:success] = pat(:delete_success, :model => 'Order', :id => "#{params[:id]}")
        File.delete(order.invoice_filename)
      else
        flash[:error] = pat(:delete_error, :model => 'Order')
      end
      redirect url(:orders, :index)
    else
      flash[:warning] = pat(:delete_warning, :model => 'Order', :id => "#{params[:id]}")
      halt 404
    end
  end

  delete :destroy_many do
    @title = "Orders"
    unless params[:order_ids]
      flash[:error] = pat(:destroy_many_error, :model => 'Order')
      redirect(url(:orders, :index))
    end
    ids = params[:order_ids].split(',').map(&:strip).map(&:to_i)
    orders = Order.find(ids)
    if Order.destroy orders
      orders.each do |o|
        File.delete(o.invoice_filename)
      end
      flash[:success] = pat(:destroy_many_success, :model => 'Order', :ids => "#{ids.to_sentence}")
    end
    redirect url(:orders, :index)
  end

end
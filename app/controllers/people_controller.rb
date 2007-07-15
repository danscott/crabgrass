class PeopleController < ApplicationController

  layout 'people'
  
  prepend_before_filter :fetch_user
  skip_before_filter :login_required, :only => ['index','list','show']

  def initialize(options={})
    super()
    @user = options[:user]   # the user context, if any
  end
  
  def index
    list
    render :action => 'list'
  end

  def list
    # @user_pages, @users = paginate :users, :per_page => 10
    if logged_in?
      @contacts = current_user.contacts
      @peers = current_user.peers
    end
    set_banner "people/banner_search", Style.new(:background_color => "#6E901B", :color => "#E2F0C0")
  end

  def show
    params[:path] = []
    folder()
  end

  def folder
    options = {:class => UserParticipation, :path => params[:path]}
    if logged_in?
      # pages the user as contributed to and that we also have access to
      options[:conditions] = "user_participations.user_id = ? " +
                             "AND user_participations.changed_at IS NOT ? " + 
                             "AND (group_parts.group_id IN (?) OR user_parts.user_id = ? OR pages.public = ?)"
      options[:values]     = [@user.id, nil, current_user.group_ids, current_user.id, true]
    else
      # public pages the user has contributed to
      options[:conditions] = "pages.public = ? " + 
                             "AND user_participations.user_id = ? " + 
                             "AND user_participations.changed_at IS NOT ?"
      options[:values]     = [@user.id, true, nil]
    end
    @pages, @page_sections = find_and_paginate_pages page_query_from_filter_path(options)
    render :action => 'show'
  end

  def tasks
    @stylesheet = 'tasks'
    options = options_for_page_participation_by(@user)
    options[:conditions] += " AND user_participations.resolved = ?"
    options[:values] << false
    options[:path] = ['type','task-list']
    @pages = find_pages(options)
    @task_lists = @pages.collect{|p|p.data}
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = 'User was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def update
    if @user.update_attributes(params[:user])
      flash[:notice] = 'User was successfully updated.'
      redirect_to :action => 'show', :id => @user
    else
      render :action => 'edit'
    end
  end

  def destroy
    @user.destroy
    redirect_to :action => 'list'
  end
    
  protected
  
  def context
    person_context
    unless ['show','index','list'].include? params[:action]
      add_context params[:action], people_url(:action => params[:action], :id => @user)
    end
  end
  
  def fetch_user 
    @user ||= User.find_by_login params[:id] if params[:id]
    @is_contact = (logged_in? and current_user.contacts.include?(@user))
    true
  end
  
end

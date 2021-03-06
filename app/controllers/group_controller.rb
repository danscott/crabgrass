
class GroupController < ApplicationController
  include GroupHelper
  helper 'task_list_page', 'tags', 'wiki' # remove task_list_page when tasks are in a separate controller

  permissions 'group', 'base_page', 'membership', 'committee', 'requests'

  stylesheet 'wiki_edit'
  stylesheet 'groups'
  stylesheet 'tasks', :action => :tasks

  javascript 'wiki_edit'
  javascript :extra, :action => :tasks

  prepend_before_filter :find_group
  before_filter :login_required, :except => [:show, :archive, :tags, :search]
  before_filter :render_sidebar

  verify :method => :post, :only => [:destroy, :update, :update_trash]

  def initialize(options={})
    super()
    @group = options[:group] # the group context, if any
  end

  def show
    params[:path] ||= ""
    params[:path] = params[:path].split('/')
    params[:path] += ['descending', 'updated_at'] if params[:path].empty?
    params[:path] += ['limit','20']

    @pages = Page.find_by_path(params[:path], options_for_group(@group))
    @announcements = Page.find_by_path('limit/3/descending/created_at', options_for_group(@group, :flow => :announcement))

    @profile = @group.profiles.send(@access)
    @committees = @group.committees_for @access
    @activities = Activity.for_group(@group, (current_user if logged_in?)).newest.unique.find(:all)

    @wiki = private_or_public_wiki()
    if may_edit_site_appearance?  
      @editable_custom_appearance = current_site.custom_appearance
    end
  end

  def archive
    @path = params[:path] || []
    @parsed = parse_filter_path(params[:path])
    @field = @parsed.keyword?('updated') ? 'updated' : 'created'

    @months = Page.month_counts(:group => @group, :current_user => (current_user if logged_in?), :field => @field)

    unless @months.empty?
      @current_year  = (Date.today).year
      @start_year    = @months[0]['year'] || @current_year.to_s
      @current_month = (Date.today).month

      # normalize path
      unless @parsed.keyword?('date')
        @path << 'date'<< "%s-%s" % [@months.last['year'], @months.last['month']]
      end
      @path.unshift(@field) unless @parsed.keyword?(@field)
      @parsed = parse_filter_path(@path)

      # find pages
      @pages = Page.paginate_by_path(@path, options_for_group(@group, :page => params[:page]))

      # set columns
      if @field == 'created'
        @columns = [:icon, :title, :created_by, :created_at, :contributors_count]
      else
        @columns = [:icon, :title, :updated_by, :updated_at, :contributors_count]
      end
    end
  end

  def tags
    tags = params[:path] || []
    path = tags.collect{|t|['tag',t]}.flatten
    if path.any?
      @pages   = Page.paginate_by_path(path, options_for_group(@group, :page => params[:page]))
      page_ids = Page.ids_by_path(path, options_for_group(@group))
      @tags    = Tag.for_taggables(Page,page_ids).find(:all)
    else
      @pages = []
      @tags  = Page.tags_for_group(:group => @group, :current_user => (current_user if logged_in?))
    end
  end

  def tasks
    @pages = Page.find_by_path('type/task/pending', options_for_group(@group))
    @task_lists = @pages.collect{|page|page.data}
    render :action => "print_tasks", :layout => false  if params[:print]
  end

  # login required
  def edit
    @group.group_setting ||= GroupSetting.new
  end

  # login required
  # edit the featured content
  def edit_featured_content
    raise PermissionDenied.new("You cannot administrate this group."[:group_administration_not_allowed_error]) unless(current_user.may?(:admin,@group))
    case params[:mode]
      when "unfeatured"
        @content = @group.find_unstatic.paginate(:page => params[:page], :per_page => 20)
      when "expired"
        @content = @group.find_expired.paginate(:page => params[:page], :per_page => 20)
      else
        @content = @group.find_static.paginate(:page => params[:page], :per_page => 20)
    end

  end

  # login required
  # mark one page as featured content
  def feature_content
    raise ErrorMessage.new("Page not part of this group"[:page_not_part_of_group]) if !(@page = @group.participations.find_by_page_id(params[:featured_content][:id]))
    if current_user.may?(:admin, @group)
      year = params[:featured_content][:"expires(1i)"]
      month = params[:featured_content][:"expires(2i)"]
      day = params[:featured_content][:"expires(3i)"]
      date = DateTime.parse("#{year}/#{month}/#{day}") if year && month && day

      case params[:featured_content][:mode].to_sym
      when :feature
        @page.static!(date || nil)
      when :reactivate
        @page.static_expired = nil
        @page.static!(date || nil)
      when :unfeature
        @page.unstatic!
      end
      redirect_to group_url(:action => 'edit_featured_content', :id => @group)
    else
      raise PermissionDenied.new("You cannot administrate this group"[:group_administration_not_allowed_error])
    end
  rescue => exc
    flash_message_now :exception => exc
    render :action => 'edit_featured_content'
  end

  # login required
  # updates the list of featured pages
  def update_featured_pages

    # use this for group_level featured content

    unstatic = @group.participations.find_all_by_static(true)
    static = @group.participations.find_all_by_page_id(params[:group][:featured_pages]) if params[:group] && params[:group][:featured_pages]
    if static
      unstatic = unstatic-static

      static.each do |p|
        p.static! unless p.static
      end
    end
    unstatic.each do |p|
      p.unstatic! if p.static
    end

   # use this for platformwide featured content
   # Page.find(params[:group][:featured_pages]).each(&:static!)
    redirect_to url_for_group(@group)
   rescue => exc
     flash_message_now :exception => exc
     render :action => 'edit'
  end

  # login required
  # post required
  # TODO: this is messed up.
  def update
    @group.update_attributes(params[:group])

    if params[:group]
      @group.profiles.public.update_attribute :may_see, params[:group][:publicly_visible_group]
      @group.profiles.public.update_attribute :may_see_committees , params[:group][:publicly_visible_committees]
      @group.profiles.public.update_attribute :may_see_members , params[:group][:publicly_visible_members]
      @group.profiles.public.update_attribute :may_request_membership , params[:group][:accept_new_membership_requests]
      @group.min_stars = params[:group][:min_stars]
      if @group.valid? && may_admin? && (params[:group][:council_id] != @group.council_id)
        # unset the current council if there is one
        @group.add_committee!(Group.find(@group.council_id), false) unless @group.council_id.nil?

        # set the new council if there is one
        new_council = @group.committees.find(params[:group][:council_id]) unless params[:group][:council_id].empty?
        @group.add_committee!(new_council, true) unless new_council.nil?
      end
    end

    if @group.save
      redirect_to :action => 'edit', :id => @group
      flash_message :success => 'Group was successfully updated.'[:group_successfully_updated]
    else
      flash_message_now :object => @group
      render :template => 'group/edit'
    end
  end

  def edit_tools
    @available_tools = current_site.available_page_types
    if request.post?
      @group.group_setting.allowed_tools = []
      @available_tools.each do |p|
        @group.group_setting.allowed_tools << p if params[p]
      end
      @group.group_setting.save

      redirect_to :action => 'edit', :id => @group
    end

    #site defaults?
    @allowed_tools =  ( ! @group.group_setting.allowed_tools.nil? ? @group.group_setting.allowed_tools : @available_tools)
  end
  
  def edit_layout
    # this whole thing is quite a hack, as the widget system will be reworked soon anyway
    # jrw, Apr 22th
    default_template_data = {"section1" => "group_wiki", "section2" => "recent_pages"}
    default_template_data.merge!({"section3" => "recent_group_pages"}) if @group.network?
    @group.group_setting ||= GroupSetting.new
    @group.group_setting.template_data ||= default_template_data
    @widgets = @group.group_setting.template_data
    if request.post?
      @group.group_setting.template_data = {}
      @group.group_setting.template_data['section1'] = params['section1']
      @group.group_setting.template_data['section2'] = params['section2']
      @group.group_setting.template_data['section3'] = params['section3']
      @group.group_setting.template_data['section4'] = params['section4']
      @group.group_setting.save

      redirect_to :action => 'edit', :id => @group
    end
  end

  # login required
  # post required
  def destroy
    if @group.users.uniq.size > 1 or @group.users.first != current_user
      flash_message :error => 'You can only delete a group if you are the last member'[:only_last_member_can_delete_group]
      redirect_to :action => 'show', :id => @group
    else
      @group.destroyed_by = current_user
      if @group.parent
        parent = @group.parent
        parent.remove_committee!(@group)
        @group.destroy
        redirect_to url_for_group(parent)
      else
        @group.destroy
        redirect_to :controller => 'groups', :action => nil
      end
    end
  end

  # login not required
  def search
    if request.post?
      path = build_filter_path(params[:search])
      redirect_to url_for_group(@group, :action => 'search', :path => path)
    else
      params[:path] = ['descending', 'updated_at'] if params[:path].empty?
      @pages = Page.paginate_by_path(params[:path], options_for_group(@group, :page => params[:page]))
      if parsed_path.sort_arg?('created_at') or parsed_path.sort_arg?('created_by_login')
        @columns = [:stars, :icon, :title, :created_by, :created_at, :contributors_count]
      else
        @columns = [:stars, :icon, :title, :updated_by, :updated_at, :contributors_count]
      end
      # don't show group members to everyone
      @visible_users = may_list_membership? ? @group.users : []
    end
    handle_rss :title => @group.name, :description => @group.summary,
               :link => url_for_group(@group),
               :image => avatar_url_for(@group, 'xlarge')
  end

  # login not required
  def trash
    if request.post?
      path = build_filter_path(params[:search])
      redirect_to url_for_group(@group, :action => 'trash', :path => path)
    else
      params[:path] = ['descending', 'updated_at'] if params[:path].empty?
      @pages = Page.paginate_by_path(params[:path], options_for_group(@group, :page => params[:page], :flow => :deleted))
      @columns = [:admin_checkbox, :icon, :title, :deleted_by, :deleted_at, :contributors_count]
      # don't show group members to everyone
      @visible_users = may_list_membership? ? @group.users : []
    end
    handle_rss :title => @group.name, :description => @group.summary,
               :link => url_for_group(@group),
               :image => avatar_url_for(@group, 'xlarge')
  end

  # post required
  def update_trash
    pages = params[:page_checked]
    if pages
      pages.each do |page_id, do_it|
        if do_it == 'checked' and page_id
          page = Page.find_by_id(page_id)
          if page
            if params[:undelete] and may_undelete_base_page?(page)
              page.undelete
            elsif params[:remove] and may_remove_base_page?(page)
              page.destroy
              ## add more actions here later
            end
          end
        end
      end
    end
    if params[:path]
      redirect_to :action => 'trash', :id => @group, :path => params[:path]
    else
      redirect_to :action => 'trash', :id => @group
    end
  end

  # login not required
  def discussions
    params[:path] = ['descending', 'updated_at'] if params[:path].empty?
    @pages = Page.paginate_by_path(['type','discussion'] + params[:path],
      options_for_group(@group, :page => params[:page], :include => {:discussion => :last_post}))
    @columns = [:icon, :title, :posts, :contributors, :last_post]
  end

  protected

  # returns a private wiki if it exists, a public one otherwise
  def private_or_public_wiki
    if @access == :private and (@profile.wiki.nil? or @profile.wiki.body == '' or @profile.wiki.body.nil?)
      public_profile = @group.profiles.public
      public_profile.create_wiki unless public_profile.wiki
      public_profile.wiki
    else
      @profile.create_wiki unless @profile.wiki
      @profile.wiki
    end
  end

  def context
    group_context
    unless action?(:show)
      add_context params[:action], url_for_group(@group, :action => params[:action], :path => params[:path])
    end
  end

  # load the @group object if we can. If we can't, or the user does not have access to
  # view the group then show an error page.
  def find_group
    @group = Group.find_by_name params[:id] if params[:id]

    if @group
      if may_see_private?
        @access = :private
      elsif may_see_public?
        @access = :public
      else
        @group = nil
      end
    end

    if @group
      return true
    else
      clear_context
      render(:template => 'dispatch/not_found', :status => (logged_in? ? 404 : 401))
      return false
    end
  end

  def render_sidebar
    ## TODO: redesign the featured system, and make it cached. This is ugly and slow.
    @left_column = render_to_string(:partial => 'sidebar') if @group
  end

  after_filter :update_view_count
  def update_view_count
    Tracking.insert_delayed(:group => @group, :user => current_user) if current_site.tracking
  end

  # called when we don't want to let on that a group exists
  # when a user doesn't have permission to see it.
  def clear_context
    @group = nil
    no_context
  end

end

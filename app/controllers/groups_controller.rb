class GroupsController < ApplicationController

  stylesheet 'groups'
  helper 'group'
  permissions 'group'

  before_filter :login_required, :only => [:create]

  def index
    user = logged_in? ? current_user : nil

     @groups = Group.visible_by(user).only_groups.recent.paginate(:all, :page => params[:page])
  end

  def directory
    user = logged_in? ? current_user : nil
    letter_page = params[:letter] || ''

    @groups = Group.visible_by(user).only_groups.alphabetized(letter_page).paginate(:all, :page => params[:page])

    # get the starting letters of all groups
    groups_with_names = Group.visible_by(user).only_groups.names_only
    @pagination_letters = Group.pagination_letters_for(groups_with_names)
  end

  def my
      @groups = current_user.groups.only_groups.alphabetized('').paginate(:all, :page => params[:page])
  end

  # login required
  def create
    @group_class = get_group_class
    @group_type = @group_class.to_s.downcase
    @parent = get_parent
    if request.get?
      @group = @group_class.new(params[:group])
    elsif request.post?
      @group = @group_class.create!(params[:group]) do |group|
        group.avatar = Avatar.new
        group.created_by = current_user
      end
      @group.profiles.public.update_attribute :may_see, params[:group][:publicly_visible_group]
      @group.profiles.public.update_attribute :may_see_committees , params[:group][:publicly_visible_committees]
      @group.profiles.public.update_attribute :may_see_members , params[:group][:publicly_visible_members]
      @group.profiles.public.update_attribute :may_request_membership , params[:group][:accept_new_membership_requests]

      # network - binding
      current_site.network.groups << @group unless current_site.network.nil?

      flash_message :success => 'Group was successfully created.'[:group_successfully_created]
      @group.add_user!(current_user)
      if @parent and current_user.may?(:admin, @parent)
        @parent.add_committee!(@group, params[:group][:is_council] == "true" )
      end

      ## DEPRECATED
      ## add_council if params[:add_council] == "true"

      redirect_to url_for_group(@group)
    end
  rescue Exception => exc
    @group = exc.record if exc.record.is_a? Group
    @group ||= Group.new
    flash_message :exception => exc
  end
       
  protected
  
  before_filter :setup_view
  def setup_view
     group_context
     set_banner "groups/banner", Style.new(:background_color => "#1B5790", :color => "#eef")
  end
  
  def get_group_class
    type = if params[:id]
      params[:id]
    elsif params[:parent_id]
      'committee'
    else
      'group'
    end
    if params[:parent_id]
      unless ['council','committee'].include? type
        raise ErrorMessage.new('Could not understand group type :type'[:dont_understand_group_type] % {:type => type})
      end
    else
      unless ['group','network'].include? type
        raise ErrorMessage.new('Could not understand group type :type'[:dont_understand_group_type] %{:type => type})
      end
    end
    Kernel.const_get(type.capitalize)
  end

  def get_parent
    parent = Group.find(params[:parent_id]) if params[:parent_id]
    if parent and not current_user.may?(:admin, parent)
      raise PermissionDenied.new('You do not have permission to create committees under %s'[:dont_have_permission_to_create_committees] % parent.name)
    end
    parent
  end

#  def add_council
#    # publicly_visible_X is deprecated in favor of the profile.
#    council_params = {
#      :short_name => @group.short_name + '_admin',
#      :full_name => @group.full_name + ' Admin',
#      :publicly_visible_group => @group.publicly_visible_group,
#      :publicly_visible_members => @group.publicly_visible_members,
#      :is_council => "true",
#      :accept_new_membership_requests => "0",
#    }
#      
#    @council = Committee.create!(council_params) do |c|
#      c.avatar = Avatar.new
#      c.created_by = current_user
#    end
#    @council.add_user!(current_user)    
#    @group.add_committee!(@council, true)
#  end

end

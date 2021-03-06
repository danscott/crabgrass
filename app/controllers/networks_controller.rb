class NetworksController < GroupsController
  
  before_filter :check_site_settings
 
  def index() redirect_to(:action => 'list') end

  def list
    letter_page = params[:letter] || ''
    
    @networks = Network.visible_by(current_user).alphabetized(letter_page).paginate(:all, :page => params[:page], :order => 'full_name')

    # get the starting letters of all networks
    networks_with_names = Network.visible_by(current_user).names_only
    @pagination_letters = Network.pagination_letters_for(networks_with_names)
  end

  def my
    letter_page = params[:letter] || ''

    @networks = Group.all_networks_for(current_user).alphabetized(letter_page).paginate(:all, :page => params[:page], :order => 'full_name')
  end

  def create
    @group_type = 'network'

    if request.get?
      @group = Network.new(params[:group])
    elsif request.post?
      if group = Group.find_by_id(params[:group_id])
        verify_access_to!(group)
      end
      @group = Network.create!(params[:group])
      if group
        @group.add_group!(group)
      else
        @group.add_user!(current_user)
      end
      current_site.network.add_group!(@group) unless current_site.network.nil?
      flash_message :success => '%s was successfully created.'.t % 'Network'.t
      redirect_to url_for_group(@group)
    end
  rescue PermissionDenied => exc
    flash_message :exception => exc
    redirect_to :controller => '/account', :action => 'login', :redirect => request.request_uri
  rescue Exception => exc
    @group = exc.record
    flash_message :exception => exc
  end
  
  protected

  def setup_view
    network_context
    set_banner "networks/banner", Style.new(:background_color => "#1B5790", :color => "#eef")
  end

  # verifies that the membership list is kosher
  def verify_access_to!(group)
    raise PermissionDenied.new('you must be a member of the group') unless current_user.member_of?(group)
  #  in_users = users.detect {|u| u == current_user}
  #  in_groups = groups.detect {|g| current_user.member_of?(g) }
  #  raise ErrorMessage.new('You must add yourself or be a member of at least one group in the membership list'[:create_network_membership_error]) unless in_users or in_groups
  end

  def check_site_settings
    unless current_site.has_networks?
      redirect_to (current_site.network ? '/' : '/me/dashboard')
    end
  end
end

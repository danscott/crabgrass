module PersonHelper

  def friend_link
    if logged_in?
      if @user.friend_of?(current_user)
        link_to :remove_from_my_contacts.t, {:controller => 'contact', :action => 'remove', :id => @user}
      elsif @user.profiles.visible_by(current_user).may_request_contact?
        link_to :add_to_my_contacts.t, {:controller => 'contact', :action => 'add', :id => @user}
      end
    end
  end

end

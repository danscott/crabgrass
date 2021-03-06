module BasePagePermission
  #  def authorized?
  #    if @page.nil?
  #      true
  #    elsif action?(:show_popup)
  #      true
  #    elsif action?(:show)
  #      current_user.may?(:view, @page)
  #    end
  #  end

  def may_create_base_page?(page = @page)
    !page or current_user.may?(:admin, page)
  end

  [:delete, :undelete].each do |action|
    alias_method "may_#{action}_base_page?".to_sym, :may_create_base_page?
  end

  # Trash
  %w[show_popup].each do |action|
    alias_method "may_#{action}_trash?".to_sym, :may_delete_base_page?
  end
  
  def may_show_base_page?(page = @page)
    !page or current_user.may?(:view, page)
  end

  # this is some really horrible stuff that i want to go away very quickly.
  # some sites want to restrict page deletion to only people who are admins
  # of groups that have admin access to the page. crabgrass does not work this
  # way and is a total violation of the permission logic. there is a better way,
  # and it should be replaced for this.
  def may_destroy_base_page?(page = @page)
    return true if page.nil?
    parts = []
    parts << page.participation_for_user(current_user)
    parts.concat page.participation_for_groups(current_user.admin_for_group_ids)
    return parts.compact.detect{|part| part.access == ACCESS[:admin]}
  end

  # we are using may_remove_page from trash controllers.
  alias_method :may_remove_base_page?, :may_destroy_base_page?

  # this can only be used from authorized? because of 
  # checking the params. Use one of
  #  - may_delete_base_page?
  #  - may_destroy_base_page?
  # from the views and helpers.
  def may_update_trash?(page=@page)
    if params[:cancel]
      may_delete_base_page?
    elsif params[:delete] && params[:type]=='move_to_trash'
      may_delete_base_page?
    elsif params[:delete] && params[:type]=='shred_now'
      may_destroy_base_page?
    else
      false
    end
  end
end

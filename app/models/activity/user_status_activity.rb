##
## NOTE: this is not used, replaced by message_wall_activity, i think.
##

class UserStatusActivity < Activity

  validates_format_of :subject_type, :with => /User/
  validates_presence_of :subject_id
  validates_presence_of :extra

  alias_attr :user,   :subject
  alias_attr :status, :extra
  
  def description(options={})
    "{user} is now {status}"[
       :activity_user_status,
       {:user => user_span(:user),:status => status.t}
    ]
  end

end


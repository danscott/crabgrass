#
# A contact request
#
# creator: user wanting a friend
# recipient: potential friend
# requestable: nil
# 
#
class RequestToFriend < Request
  
  validates_format_of :recipient_type, :with => /User/

  def validate_on_create
    if UserRelation.find_by_user_id_and_partner_id(created_by_id, recipient_id)
      errors.add_to_base('Contact already exists')
    end
    if RequestToFriend.find_by_created_by_id_and_recipient_id_and_state(created_by_id, recipient_id, state)
      errors.add_to_base('Request already exists for %s'[:request_exists_error] % recipient.name)
    end
  end

  def requestable_required?() false end

  def may_create?(user)
    true
  end

  def may_destroy?(user)
    user == recipient or user == created_by
  end

  def may_approve?(user)
    recipient == user
  end

  def may_view?(user)
    user == recipient or may_approve?(user)
  end

 
  def after_approval
    recipient.add_contact!(created_by, :type => :friend)
  end

  def description
    ":user would like to be the contact of :other_user"[:request_to_friend_description] % {
       :user => user_span(created_by), :other_user => user_span(recipient)
    }
  end

end

class ContactObserver < ActiveRecord::Observer

  def after_create(contact)
    if activity = FriendActivity.find_twin(contact.user, contact.contact)
      key = activity.key
    else
      key = rand(Time.now)
    end
    FriendActivity.create!(:user => contact.user, :other_user => contact.contact, :key => key)
  end

end


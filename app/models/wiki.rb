=begin

  This is a generic versioned wiki, primarily used by the WikiPage,
  but also used directly sometimes by other classes (like for Group's
  landing page wiki's).

=end

class Wiki < ActiveRecord::Base

  belongs_to :locked_by, :class_name => 'User', :foreign_key => 'locked_by_id'
  belongs_to :user

  # a wiki can be used in multiple places: pages or profiles
  has_many :pages, :as => :data
  has_one :profile
  
  acts_as_versioned :if => :save_new_version?

  self.non_versioned_columns << 'locked_by_id' << 'locked_at'

  #### LOCKING #######################
  
  # a word about timezones:
  # to get an attribute in UTC, you must do:
  #   wiki.locked_at_before_type_cast 
  # otherwise, the times reported by active record objects
  # are always local.

  LOCKING_PERIOD = 120.minutes

  def lock(time, locked_by)
    without_locking do
      without_revision do
        without_timestamps do
          update_attributes(:locked_at => time, :locked_by => locked_by)
        end
      end
    end
  end

  def unlock(user=nil)
    lock(nil,nil) if user.nil? or locked_by == user
  end
   
  def lock_duration(time)
    ((time - locked_at) / 60).to_i unless locked_at.nil?
  end  
  
  def locked?(comparison_time=nil)
    comparison_time ||= Time.zone.now
    locked_at + LOCKING_PERIOD > comparison_time unless locked_at.nil?
  end

  # returns true if the page is not locked by someone else
  def editable_by?(user)
    not locked? or locked_by == user
  end
  
  ##### VERSIONING #############################

  # only save a new version if the body has changed
  # and was not previously nil
  def save_new_version?
    self.body_changed? and self.body_was.any?
  end
  
  # returns true if the last version was created recently by this same author.
  def recent_edit_by?(author)
    (user == author) and updated_at and (updated_at > 30.minutes.ago)
  end 
  
  # returns first version since @time@
  def first_since(time)
    return nil unless time
    versions.first :conditions => ["updated_at <= :time", {:time => time}],
      :order => "updated_at DESC"
  end

  ##### SAVING ####################################
  
  # 
  # a smart update of the wiki, taking into account locking
  # and the last time the wiki was saved by the same person.
  #
  # tries to save, throws an exception if anything goes wrong.
  # possible exceptions:
  #   ActiveRecord::StaleObjectError
  #   ErrorMessage
  #
   
  def smart_save!(params)
    restore_body(params)

    if params[:version] and version > params[:version].to_i
      raise ErrorMessage.new("can't save your data, someone else has saved new changes first.")
    end
 
    unless params[:user] and params[:user].is_a? User
      raise ErrorMessage.new("User is required.")
    end
    
    unless editable_by?(params[:user])
      raise ErrorMessage.new("Cannot save your data, someone else has locked the page.")
    end

    if recent_edit_by?(params[:user])
      save_without_revision
      versions.find_by_version(version).update_attributes(:body => body, :body_html => body_html, :updated_at => Time.now)
    else
      self.user = params[:user]
      save!
    end  
  end
  
  def restore_body(params)
    if params[:section].blank?
      # editing the whole document
      self.body = params[:body]
    else
      sections = self.sections
      sections[params[:section].to_i] = params[:body]
      self.body = sections.join('')
    end
  end

  ##### RENDERING #################################
 
  def body=(value)
    write_attribute(:body, value)
    write_attribute(:body_html, "")
  end
 
  def clear_html
    update_attribute(:body_html, nil)
  end

  # render_html is responsible for rendering wiki text to html markup.
  #
  # This rendering, however, is not handled by the wiki class: the block passed
  # to render_html() does the conversion.
  #
  # render_html() should be called whenever the body_html needs to be shown, but
  # the block will only actually get called if body_html needs updating.
  #
  # Example usage:
  #
  #   wiki.body_html # << not valid yet
  #   wiki.render_html do |text|
  #      GreenCloth.new(text).to_html
  #   end
  #   wiki.body_html # << now it is valid
  #
  def render_html(&block)
    if body.empty?
      self.body_html = "<p></p>"
    elsif body_html.empty? 
      self.body_html = block.call(body)
    end
    if body_html_changed?
      without_timestamps do
        save_without_revision!
      end
    end
  end
  
  ##### RELATIONSHIP TO GROUPS ###################
  
  # clears the rendered html. this is called
  # when a group's name is changed or some other event happens
  # which might affect how the html is rendered by wholecloth.
  # this only clears the primary group's wikis, which should be fine
  # because default_group_name just uses the primary group's name.
  def self.clear_all_html(group)
    # for wiki's owned by pages
    Wiki.connection.execute("UPDATE wikis set body_html = NULL WHERE id IN (SELECT data_id FROM pages WHERE data_type='Wiki' and group_id = #{group.id.to_i})")
    # for wiki's owned by groups
    Wiki.connection.execute("UPDATE wikis set body_html = NULL WHERE id IN (SELECT wiki_id FROM profiles WHERE entity_id = #{group.id.to_i})")
  end
  
  def default_group_name
    if page and page.group_name
      #.sub(/\+.*$/,'') # remove everything after +
      page.group_name
    elsif profile
      profile.entity.name
    else
      'page'
    end
  end
  
  #### RELATIONSHIP TO PAGES ########
    
  # we do this so that we can access the page even before page or wiki are saved
  def page
    return pages.first if pages.any?
    return @page
  end
  def page=(p)
    @page = p
  end
  
  #### SECTIONS ########

  # returns an array of all sections
  def sections
    GreenCloth.new(body).sections
  end
end

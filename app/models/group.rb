# == Schema Information
# Schema version: 24
#
# Table name: groups
#
#  id             :integer(11)   not null, primary key
#  name           :string(255)   
#  summary        :string(255)   
#  url            :string(255)   
#  type           :string(255)   
#  parent_id      :integer(11)   
#  admin_group_id :integer(11)   
#  council        :boolean(1)    
#  created_at     :datetime      
#  updated_at     :datetime      
#  avatar_id      :integer(11)   


#  group.name       => string
#  group.summary    => string
#  group.url        => string
#  group.council    => boolean
#  group.created_on => date
#  group.updated_on => time
#  group.children   => groups
#  group.parent     => group
#  group.admin_group  => nil or group
#  group.nodes      => nodes
#  group.users      => users
#  group.picture    => picture


class Group < ActiveRecord::Base
  track_changes :name
  
  has_one :admin_group, :class_name => 'Group', :foreign_key => 'admin_group_id'

  has_and_belongs_to_many :users, :join_table => :memberships

  # relationship to pages
  has_many :participations, :class_name => 'GroupParticipation', :dependent => :delete_all
  has_many :pages, :through => :participations do
    def pending
      find(:all, :conditions => ['resolved = ?',false], :order => 'happens_at' )
    end
  end

  belongs_to :avatar
  belongs_to :public_home, :class_name => 'Wiki', :foreign_key => 'public_home_id'
  belongs_to :private_home, :class_name => 'Wiki', :foreign_key => 'private_home_id'
  
  has_many :tags, :finder_sql => %q[
    SELECT DISTINCT tags.* FROM tags INNER JOIN taggings ON tags.id = taggings.tag_id
    WHERE taggings.taggable_type = 'Page' AND taggings.taggable_id IN
      (SELECT pages.id FROM pages INNER JOIN group_participations ON pages.id = group_participations.page_id
      WHERE group_participations.group_id = #{id})]
      
#  has_many :federations
#  has_many :networks, :through => :federations

  # committees are children! they must respect their parent group.  
  acts_as_tree :order => 'name'
  alias :committees :children
  
#  has_and_belongs_to_many :locations,
#    :class_name => 'Category'
#  has_and_belongs_to_many :categories
  
  # validations
  
  validates_handle :name

  #######################################################################
  # methods
  
  def add_page(page, attributes)
    page.group_participations.create attributes.merge(:page_id => page.id, :group_id => id)
    page.changed :groups
  end

  def remove_page(page)
    page.groups.delete(self)
    page.changed :groups
  end
  
  def may?(perm, page)
    may!(perm,page) rescue false
  end
  
  # perm one of :view, :edit, :admin
  # this is still a basic stub. see User.may!
  def may!(perm, page)
    gpart = page.participation_for_group(self)
    return true if gpart
    raise PermissionDenied
  end
   
  def to_param
    return name
  end
  
  def display_name
    full_name.any? ? full_name : name
  end
  
  def short_name
    name
  end
  
  def banner_style
    @style ||= Style.new(:color => "#eef", :background_color => "#1B5790")
  end
   
  def committee?; instance_of? Committee; end
  def network?; instance_of? Network; end
  def normal?; instance_of? Group; end
    
  protected
  
  def after_save
    if changed? :name
      update_group_name_of_pages
      Wiki.clear_all_html(self) # in case there were links using the old name
      committees.each {|c| c.update_name }
    end
  end
   
  def update_group_name_of_pages
    Page.connection.execute "UPDATE pages SET `group_name` = '#{self.name}' WHERE pages.group_id = #{self.id}"
  end
   
end

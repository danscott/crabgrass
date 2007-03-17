# == Schema Information
# Schema version: 24
#
# Table name: pages
#
#  id              :integer(11)   not null, primary key
#  title           :string(255)   
#  created_at      :datetime      
#  updated_at      :datetime      
#  happens_at      :datetime      
#  resolved        :boolean(1)    
#  public          :boolean(1)    
#  needs_attention :boolean(1)    
#  created_by_id   :integer(11)   
#  updated_by_id   :integer(11)   
#  summary         :string(255)   
#  controller      :string(255)   
#  tool_id         :integer(11)   
#  tool_type       :string(255)   
#

class Page < ActiveRecord::Base

  # to be set by subclasses (ie tools)
  class_attribute :controller, :model, :icon, :tool_type, :internal?
  
  acts_as_taggable

  ### associations ###  
  
  belongs_to :data, :polymorphic => true
  has_one :discussion, :dependent => :destroy
  
  # relationship of this page to users
  belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
  belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
  has_many :user_participations, :dependent => :destroy
  has_many :users, :through => :user_participations do
    def with_access
      find(:all, :conditions => 'access IS NOT NULL')
    end
    def participated
      find(:all, :conditions => 'changed_at IS NOT NULL')
    end
  end

  # like users.with_access, but uses already included data
  def users_with_access
    user_participations.collect{|part| part.user if part.access }.compact
  end
  
  # like users.participated, but uses already included data
  def users_participated
    user_participations.collect{|part| part.user if part.changed_at }.compact
  end
  
  # like user_participations.find_by_user_id, but uses already included data
  def participation_for_user(user) 
    user_participations.detect{|p| p.user_id==user.id }
  end
  
  # relationship of this page to groups
  has_many :group_participations, :dependent => :destroy
  has_many :groups, :through => :group_participations

  # reciprocal links between pages
#  has_and_belongs_to_many :pages,
#    :class_name => "Page",
#    :join_table => "links",
#    :association_foreign_key => "other_page_id",
#    :foreign_key => "page_id",
#    :uniq => true,
#    :after_add => :reciprocate_add,
#    :after_remove => :reciprocate_remove

  ### validations ###
  
  validates_presence_of :title
  validates_associated :data
  
  ### callbacks ###

  def before_create
    created_by = User.current if User.current
    self.type = self.class.to_s # to work around bug in rails with namespaced models http://dev.rubyonrails.org/ticket/7630
    true
  end
 
  def before_save
    self.updated_by = User.current if User.current
    true
  end
  
  def reciprocate_add(other_page)
    other_page.pages << self unless other_page.pages.include?(self)
  end
  
  def reciprocate_remove(other_page)
    other_page.pages.delete(self) rescue nil
  end

  ### methods ###
    
  # add a group or user participation to this page
  def add(entity, attributes={})
    if entity.is_a? Enumerable
      entity.each do |e|
        e.add_page(self,attributes)
      end
    else
      entity.add_page(self,attributes)
    end
    self
  end
      
  # remove a group or user participation from this page
  def remove(entity)
    if entity.is_a? Enumerable
      entity.each do |e|
        e.remove_page(self)
      end
    else
      entity.remove_page(self)
    end
  end
  
  def unresolve
    resolve(false)
  end
  def resolve(value=true)
    user_participations.each do |up|
      up.resolved = value
      up.save
    end
    resolved = value
    save
  end
  
  def self.make(function,options={})
    PageStork.send(function, options)
  end

  #def new_tool
  #  tool = model.create
  #end
  
end

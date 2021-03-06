module UrlHelper

  ##
  ## REFERER
  ##

  def referer
    @referer ||= get_referer
  end
 	   
  def get_referer
    return '/' unless raw = request.env["HTTP_REFERER"]
    server = request.host_with_port
    prot = request.protocol
    if raw.starts_with?("#{prot}#{server}/")
      raw.sub(/^#{prot}#{server}/, '').sub(/\/$/,'')
    else
      '/'
    end
  end

  ##
  ## GROUPS
  ##

  def url_for_group(arg, options={})
    name_and_url_for_group(arg,options)[1]
  end

  # see function name_and_path_for_group for description of options
  def link_to_group(arg, options={})
    if arg.is_a? Integer
      @group_cache ||= {}
      # hacky fix for error when a page persists after it's group is deleted --af
      # what is this trying to do? --e
      if not @group_cache[arg]
        if Group.exists?(arg)
          @group_cache[arg] = Group.find(arg)
        else
          return ""
        end
      end
      # end hacky fix
      arg = @group_cache[arg]
    end
    
    display_name, path = name_and_url_for_group(arg,options)
    style = options[:style] || ""
    label = options[:label] || display_name
    klass = options[:class] || 'name_icon'
    avatar = ''
    if options[:avatar_as_separate_link] # not used for now
      avatar = link_to(avatar_for(arg, options[:avatar], options), :style => style)
    elsif options[:avatar]
      klass += " #{options[:avatar]}"
      if arg and arg.avatar
        url = avatar_url(:id => (arg.avatar||0), :size => options[:avatar])
      else
        url = avatar_url(:id => 0, :size => options[:avatar])
      end
      style = "background-image:url(#{url});" + style
    end
    avatar + link_to(label, path, :class => klass, :style => style)
  end


  # if you pass options[:full_name] = true, committees will have the string
  # "group+committee" (default does not include leading "group+")
  # 
  # options[:display_name] = true for groups will yield the descriptive name for display, if one exists
  #
  # This function accepts a string, a group_id (integer), or a class derived from a group
  #
  # If options[:text] = "boop %s beep", the group name will be 
  # substituted in for %s, and the display name will be "boop group_name beep"
  #
  # If options[:action] is not included it is assumed to be show, and otherwise
  # the the link goes to "/group/action/group_name'
  def name_and_url_for_group(arg,options={})
    if arg.instance_of? Integer
      arg = Group.find(arg)
    elsif arg.instance_of? String
      group = Group.find_by_name(arg)
      name = arg
      display_name = (group ? group.display_name : name)
    elsif arg.is_a? Group
      controller = arg.class.name.downcase if arg.network?
      name = arg.name
      if options[:full_name]
        display_name = arg.full_name
      elsif options[:short_name]
        display_name = arg.name
      else
        display_name = arg.display_name
      end
    end

    display_name ||= name
    display_name = options[:text] % display_name if options[:text]
    action = options[:action] || 'show'
    if options[:path]
      if options[:path].is_a? String
        path = options[:path].split('/')
      elsif options[:path].is_a? Array
        path = options[:path]
      end
      path = path.select(&:any?)
    else
      path = nil
    end

    if action == 'show'
      url = "/#{name}"
    else
      controller ||= 'group'
      url = {:controller => controller, :action => action, :id => name}
      url[:path] = path if path
    end
    [display_name, url]  
  end

  def group_search_url(*path)
    url_for_group(@group, :action => 'search', :path => path)
  end

  def group_trash_url(*path)
    url_for_group(@group, :action => 'trash', :path => path)
  end

  ##
  ## USERS
  ##

  # arg might be a user object, a user id, or the user's login
  def login_and_path_for_user(arg, options={})
    if arg.is_a? Integer
      # this assumes that at some point simple id based finds will be cached in memcached
      user = User.find(arg)
      login = user.login 
      display = user.display_name
    elsif arg.is_a? String
      user = User.find_by_login(arg)
      login = arg
      display = user.nil? ? arg : user.display_name
    elsif arg.is_a? User
      login = arg.login
      display = arg.display_name
    end
    #link_to login, :controller => '/people', :action => 'show', :id => login if login
    action = options[:action] || 'show'
    if action == 'show'
      path = "/#{login}"
    else
      path = "/person/#{action}/#{login}"
    end
    [login, path, display]
  end
  
  def url_for_user(arg, options={})
    login, path, display = login_and_path_for_user(arg,options)
    path
  end
  
  # creates a link to a user, with or without the avatar.
  # avatars are displayed as background images, with padding
  # set on the <a> tag to make room for the image.
  # accepts:
  #  :avatar => [:small | :medium | :large]
  #  :label -- override display_name as the link text
  #  :style -- override the default style
  #  :class -- override the default class of the link (name_icon)
  def link_to_user(arg, options={})
    login, path, display_name = login_and_path_for_user(arg,options)
    style = options[:style] || ""                   # allow style override
    label = options[:login] ? login : display_name  # use display_name for label by default
    label = options[:label] || label                # allow label override
    klass = options[:class] || 'name_icon'
    style += " display:block" if options[:block]
    avatar = ''
    if options[:avatar_as_separate_link] # not used for now
      avatar = link_to(avatar_for(arg, options[:avatar], options), :style => style)
    elsif options[:avatar]
      klass += " #{options[:avatar]}"
      url = avatar_url(:id => (arg.avatar||0), :size => options[:avatar])
      style = "background-image:url(#{url});" + style
    end
    avatar + link_to(label, path, :class => klass, :style => style)
  end

  def person_search_url(*path)
    url_for_user(@user, :action => 'search', :path => path)
  end


  ##
  ## GENERIC PERSON OR GROUP 
  ##

  def url_for_entity(entity, options={})
    if entity.is_a? User
      url_for_user(entity, options)
    elsif entity.is_a? Group
      url_for_group(entity, options)
    end
  end

  def link_to_entity(entity, options={})
    if entity.is_a? User
      link_to_user(entity, options)
    elsif entity.is_a? Group
      link_to_group(entity, options)
    end
  end

  # Display a group or user, without a link. All such displays should be made by
  # this method.
  #
  # options:
  #   :avatar => nil | :xsmall | :small | :medium | :large | :xlarge (default: nil)
  #   :format => :short | :full | :both | :hover | :twolines (default: full)
  #   :block => false | true (default: false)
  #   :class => passed through to the tag as html class attr
  #   :style => passed through to the tag as html style attr
  def display_entity(entity, options={})
    options = {:format => :full}.merge(options)
    display = nil; hover = nil
    options[:class] = [options[:class], 'entity'].join(' ')
    options[:block] = true if options[:format] == :twolines

    if options[:avatar]
      url = avatar_url(:id => (entity.avatar||0), :size => options[:avatar])
      options[:class] = [options[:class], "name_icon", options[:avatar]].compact.join(' ')
      options[:style] = [options[:style], "background-image:url(#{url})"].compact.join(';')
    end
    display, title, hover = case options[:format]
      when :short then [entity.name, h(entity.display_name), nil]
      when :full then [h(entity.display_name), entity.name, nil]
      when :both then [h(entity.both_names), nil, nil]
      when :hover then [entity.name, nil, h(entity.display_name)]
      when :twolines then ["<div class='name'>%s</div>%s"%[entity.name, (h(entity.display_name) if entity.name != entity.display_name)], nil, nil]
    end
    if hover
      display += content_tag(:b,hover)
      options[:style] = [options[:style], "position:relative"].compact.join(';')
      # ^^ to allow absolute popup with respect to the name
    end
    element = options[:block] ? :div : :span
    content_tag(element, display, :style => options[:style], :class => options[:class], :title => title)
  end

  # used to build an rss link from the current params[:path]
  def current_rss_path
    path = params[:path].clone || []
    path << 'rss' unless path.last == 'rss'
    return path
  end

  ##
  ## TAGGING
  ##

  def tag_link(tag, group_name=nil, user_name=nil, css_class='tag2')
    name = CGI.escape tag.name
    if group_name  
      link_path = "/group/tags/#{group_name}/#{name}"
#    elsif user_name 
#      link_path = "/person/tags/#{user_name}/#{name}"
    else
      link_path = "/me/search/tag/#{name}"
    end
    link_to h(tag.name), link_path, :class => css_class

  end

end

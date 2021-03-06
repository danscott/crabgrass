# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def link_char(links)
    if links.first.is_a? Symbol
      char = links.shift
      return ' &bull; ' if char == :bullet
      return ' | '
    else
      return ' | '
    end
  end

  ## makes this: link | link | link
  def link_line(*links)
    char = content_tag(:em, link_char(links))
    content_tag(:div, links.compact.join(char), :class => 'link_line')
  end
  def link_span(*links)
    char = content_tag(:em, link_char(links))
    content_tag(:span, links.compact.join(char), :class => 'link_line')
  end

  # returns the first of the args where any? returns true
  def first_with_any(*args)
    for str in args
      return str if str.any?
    end
  end
  
  ## coverts bytes into something more readable 
  def friendly_size(bytes)
    return unless bytes
    if bytes > 1.megabyte
      '%s MB' % (bytes / 1.megabyte)
    elsif bytes > 1.kilobyte
      '%s KB' % (bytes / 1.kilobyte)
    else
      '%s B' % bytes
    end
  end
   
  def once?(key)
    @called_before ||= {}
    return false if @called_before[key]
    @called_before[key]=true
  end
  
  def logged_in_since
    session[:logged_in_since] || Time.now
  end

  def option_empty(label='')
    %(<option value=''>#{label}</option>)
  end

  # from http://www.igvita.com/2007/03/15/block-helpers-and-dry-views-in-rails/
  # Only need this helper once, it will provide an interface to convert a block into a partial.
  # 1. Capture is a Rails helper which will 'capture' the output of a block into a variable
  # 2. Merge the 'body' variable into our options hash
  # 3. Render the partial with the given options hash. Just like calling the partial directly.
  def block_to_partial(partial_name, options = {}, &block)
    options.merge!(:body => capture(&block))
    concat(render(:partial => partial_name, :locals => options), block.binding)
  end

  def mini_search_form(options={})
    unless params[:action] == 'search' or params[:controller] =~ /search|inbox/
      render :partial => 'pages/mini_search', :locals => options
    end
  end

  def letter_pagination_labels
    $letter_pagination_labels_list ||= ("A".."Z").to_a + ["#"]
  end

  def letter_pagination_links(url_opts = {}, pagination_opts = {}, &url_proc)
    url_proc = method :url_for if url_proc.nil?
    available_letters = pagination_opts[:available_letters]
    if available_letters and !available_letters.grep(/^[^a-z]/i).empty?
      # we have things that are not letters in the mix
      available_letters << "#"
    end

    render  :partial => 'pages/letter_pagination',
                        :locals => {:letter_labels => letter_pagination_labels,
                                    :available_letters => pagination_opts[:available_letters],
                                    :url_proc => url_proc,
                                    :url_opts => url_opts,
                                    }
  end

  # 
  # Default pagination link options:
  # 
  #   :class        => 'pagination',
  #   :prev_label   => '&laquo; Previous',
  #   :next_label   => 'Next &raquo;',
  #   :inner_window => 4, # links around the current page
  #   :outer_window => 1, # links around beginning and end
  #   :separator    => ' ',
  #   :param_name   => :page,
  #   :params       => nil,
  #   :renderer     => 'WillPaginate::LinkRenderer',
  #   :page_links   => true,
  #   :container    => true
  #
  def pagination_links(things, options={})
    defaults = {:renderer => DispatchLinkRenderer, :prev_label => "&laquo; %s" % "prev"[:pagination_previous], :next_label => "%s &raquo;" % "next"[:pagination_next]}
    will_paginate(things, defaults.merge(options))
  end
  
  def options_for_my_groups(selected=nil)
    options_for_select([['','']] + current_user.groups.sort_by{|g|g.name}.to_select(:name), selected)
  end
  
  def options_for_language(selected=nil)  
    selected ||= session[:language_code].to_s
    selected = selected.sub(/_\w\w$/, '') # remove locale
    options_array = LANGUAGES.collect {|lang| [lang.name, lang.code.sub(/_\w\w$/,'')]}
    options_for_select(options_array, selected)
  end

  def header_with_more(tag, klass, text, more_url=nil)
    span = more_url ? " " + content_tag(:span, "&bull; " + link_to('more'[:see_more_link]+ARROW, more_url)) : ""
    content_tag tag, text + span, :class => klass
  end

  # converts span tags from a model (request or activity) and inserts links
  def expand_links(text)
    text.gsub(/<span class="user">(.*?)<\/span>/) do |match|
      link_to_user($1)
    end.gsub(/<span class="group">(.*?)<\/span>/) do |match|
      link_to_group($1)
    end
  end

  def side_list_li(options)
     active = url_active?(options[:url]) || options[:active]
     content_tag(:li, link_to_active(options[:text], options[:url], active), :class => "small_icon #{options[:icon]}_16 #{active ? 'active' : ''}")
  end

  def edit_site_custom_appearance_link(site)
    if site.custom_appearance and logged_in? and current_user.may?(:admin, site)
      link_to "edit custom appearance"[:edit_custom_appearance], edit_custom_appearance_url(site.custom_appearance)
    end
  end

  def formatting_reference_link
   %Q{<div class='formatting_reference'><a class="small_icon help_16" href="/static/greencloth" onclick="quickRedReference(); return false;">%s</a></div>} % "formatting reference"[:formatting_reference_link]
  end

  def help(symbol)
    symbol = "#{symbol}_help".to_sym
    text = ""[symbol]
    text.any? ? text : nil
  end

end

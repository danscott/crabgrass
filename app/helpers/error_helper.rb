# this requires ActionView::Helpers::TagHelper 

module ErrorHelper

  ##
  ## GENERATING NOTICES
  ##

  #
  # a one stop shopping function for flash messages
  # usage:
  # message :object => @user
  # message :error => 'you messed up good'
  # message :success => 'yeah, you rock'
  #
  ## TODO: destroy with helper, replace with flash_message
  ## and flash_message_now
  def message(opts)    
    if opts[:success]
      flash[:notice] = opts[:success]
    elsif opts[:error]
      flash[:type] = 'error'
      if opts[:later]
        flash[:error] = opts[:error].to_s
      else
        flash.now[:error] = opts[:error].to_s
      end
    elsif opts[:object]
      object = opts[:object]
      unless object.errors.empty?        
        flash.now[:error] = "Changes could not be saved."[:alert_not_saved]
        flash.now[:text] ||= ""
        flash.now[:text] += content_tag "p", "There are problems with the following fields"[:alert_field_errors] + ":"
        flash.now[:text] += content_tag "ul", object.errors.full_messages.collect { |msg| content_tag("li", msg) }
        flash.now[:errors] = object.errors
      end
    end
  end

  #
  # Direct manipulation of the message display: 
  #
  #   flash_message :title => 'hello', :text => 'have a nice day', :type => 'info'
  #   flash_message :title => 'wrong', :text => 'you messed up', :type => 'error'
  #
  # 
  # Shortcuts:
  # 
  #   flash_message :success => true
  #      (same as :type => 'info', :title => 'Changes saved')
  #
  #   flash_message :success => 'yeah'
  #      (same as :type => 'info', :text => 'yeah', :title => 'Changes Saved')
  #
  #   flash_message :error => true
  #      (same as :type => 'error', :title => 'Changes could not be saved')
  #
  #   flash_message :error => 'no'
  #      (same as :type => 'error', :title => 'Changes could not be saved', :text => 'no')
  #
  # Special objects:
  #
  #   flash_message :exception => exc
  #
  #   flash_message :object => @robot
  #
  # Some things you can add more than once, and they will be appended to the display:
  #
  #   flash_message :error => 'could not save'
  #   flash_message :error => 'and you are doing it wrong'
  #
  # In this case, both errors will be displayed. Other attributes can only be set once,
  # like title or type.
  #
  #
  def flash_message(options)
    add_flash_message(flash, options)
  end

  def flash_message_now(options)
    add_flash_message(flash.now, options)
  end

  ##
  ## DISPLAYING NOTICES
  ##

  # like message() but can be used in rjs templates
  # it uses javascript to rewrite the message area
  # page.replace_html 'message', message_text(:object => @page) unless @page.valid?
  def message_text(option)
    add_flash_message(flash, options)
    display_messages
  end

  # display flash messages with appropriate styling
  def display_messages()
    @display_message ||= begin
      if flash[:type].empty?
        ""
      else
        if flash[:title].empty?
          flash[:title] =  "Changes could not be saved"[:alert_not_saved] if flash[:type] == 'error'
          flash[:title] =  "Changes saved"[:alert_saved]                  if flash[:type] == 'info'
        end
        build_notice_area(flash[:type], flash[:title], flash[:text])
      end
    end
  end

  # use by ajax
  ## TODO: remove, replace with message_text()
  def notify_errors(title, errors)
     text = "<ul>" + errors.collect{|e|"<li>#{e}</li>"}.join("\n") + "</li>"
     build_notice_area('error', title, text)
  end
 
   # use by ajax
  ## TODO: remove, replace with message_text()
  def notify_infos(title, infos)
     text = "<ul>" + infos.collect{|e|"<li>#{e}</li>"}.join("\n") + "</li>"
     build_notice_area('info', title, text)
  end

  private
  
  def build_notice_area(type, title, text)
    heading = content_tag(:h2, title, :class => "big_icon #{type}_48")
    heading = content_tag(:div, heading, :class => 'heading')
    if text and text.any?
      text = content_tag(:div, text, :class => 'text')
    else
      text = ""
    end
    heading_and_text = content_tag(:div, heading+text, :class => type)
    content_tag(:div, heading_and_text, :class => 'notice')
  end

  #
  # parses options to build the appropriate objects in the particular flash
  # (flash or flash.now)
  # 
  # this method should not be called directly. intead use flash_message and
  # flash_message_now
  #
  # options:
  # :title
  # :object | :success | :error | :exception
  #
  def add_flash_message(flsh, options)
    flsh[:text] ||= ""
    flsh[:text] += content_tag(:p, options[:text]) if options[:text]
    flsh[:title] = options[:title] || flsh[:title]
    if options[:exception]
      exc = options[:exception]
      if exc.is_a? PermissionDenied
        add_flash_message(flsh, :text => options[:text], :title => 'Permission Denied'[:alert_permission_denied], :error => exc.to_s)
      elsif exc.is_a? ErrorMessages
        add_flash_message(flsh, :text => options[:text], :title => exc.title, :error => exc.errors)
      elsif exc.is_a? ErrorMessage
        add_flash_message(flsh, :text => options[:text], :title => 'Error'[:alert_error], :error => exc.to_s)
      elsif exc.is_a? ActiveRecord::RecordInvalid
        add_flash_message(flsh, :text => options[:text], :object => exc.record)
      else
        add_flash_message(flsh, :text => "#{:error.t}: #{exc.class}", :error => exc.to_s)
      end
    elsif options[:object]
      object = options[:object]
      unless object.errors.empty?        
        flsh[:type] = 'error'
        flsh[:text] += content_tag :p, "There are problems with the following fields"[:alert_field_errors] + ":"
        flsh[:text] += content_tag :ul, object.errors.full_messages.collect { |msg| content_tag :li, msg }
      end
    elsif options[:error]
      flsh[:type] = 'error'
      if options[:error] === true
        # use defaults
      elsif options[:error].any?
        flsh[:text] += content_tag :p, options[:text] if options[:text]
        flsh[:text] += content_tag :ul, options[:error].to_a.collect{|msg|
          content_tag :li, h(msg)
        }
      end
    elsif options[:success]
      flsh[:type] = 'info'
      if options[:success] === true
        # use defaults
      elsif options[:success].any?
        flsh[:text] += content_tag :p, options[:text] if options[:text]
        flsh[:text] += content_tag :ul, options[:success].to_a.collect{|msg|
          content_tag :li, h(msg)
        }
      end
    end
  end

  def exception_detailed_message(exception)
    message = exception.clean_message
    file, line = exception.backtrace.first.split(":")[0, 2]
    if File.exists?(file)
      message << "\n\n"
      code = File.readlines(file)
      line = line.to_i
      min = [line - 2, 0].max
      max = line + 2
      (min..max).each do |n|
        if n == line
          message << "=> "
        else
          message << "   "
        end
        message << ("%4d" % n)
        message << code[n]
      end
    end
    message
  end
end


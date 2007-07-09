# GreenCloth
# ==========
# 
#
# GreenCloth is derived from RedCloth, the defacto
# text to html converter for ruby.
#
# Improvements from RedCloth
# --------------------------
#
# * URLs are not accidently formatted (for example if a word *like/this* appears in the url, it will not be bold).
#
# * Automagic URL recognition (ie http://riseup.net is turned into a link).
#
# * Hard breaks are enabled, and work better (applied in fewer situations).
#
# * Added "dictionary" block, which looks like a hanging indent.
#
# Major changes from RedCloth
# ---------------------------
#
# * Totally different linking system
#
# * No HTML of any sort, except for <pre> and <code> tags.
#
# * No horizontal rules.
#
# * Leading spaces create blockquotes, not <pre><code>
#
# GreenCloth Linking
# ------------------
#
# [A good page]                  ---> <a href="/mygroup/a-good-page">A good page</a>
# [I like pages -> A good page]  ---> <a href="/mygroup/a-good-page">I like pages</a>
# [I like pages -> 2452]         ---> <a href="/mygroup/2452">I like pages</a>
# [other group/A good page]      ---> <a href="/other-group/a-good-page">A good page</a>
# [I like pages -> other-group/] ---> <a href="/other-group/i-like-pages">I like pages</a>
# http://riseup.net              ---> <a href="http://riseup.net">riseup.net</a>
#
#
#
# Here are the specific Redcloth rules we have enabled (marked with !):
# 
# textile rules
#   http://hobix.com/textile/
#   :textile               all the following textile rules, in that order
#   :refs_textile          Textile references (i.e. [hobix]http://hobix.com/)
# ! :block_textile_table   Textile table block structures. eg: |a|b|c|
# ! :block_textile_lists   Textile list structures. eg: * item\n** inset item
# ! :block_textile_prefix  Textile blocks with prefixes (i.e. bq., h2., etc.)
# ! :inline_textile_image  Textile inline images
#   :inline_textile_link   Textile inline links
# ! :inline_textile_span   Textile inline spans
# ! :glyphs_textile        Textile entities (such as em-dashes and smart quotes)
#
# markdown rules
#   http://daringfireball.net/projects/markdown/syntax
#   :markdown             all the following markdown rules, in that order.
#   :refs_markdown         Markdown references.       eg: [hobix]: http://hobix.com/
# ! :block_markdown_setext Markdown setext headers.   eg: ---- or =====
#   :block_markdown_atx    Markdown atx headers.      eg: ### or ##
#   :block_markdown_rule   Markdown horizontal rules. eg: * * *, or ***, or ----, or - - -
# ! :block_markdown_bq     Markdown blockquotes.      eg: > indented
#   :block_markdown_lists  Markdown lists.            eg: -, *, or +, or 1.
#   ^^^^  NOT YET WORKING as of redcloth 3.0.4
#   :inline_markdown_link  Markdown links.            eg: [This link](http://example.net/), or <http://example.net>
# 
# Redcloth restrictions: 
# 
# ! :filter_html   does not allow html to get passed through. (not working in redcloth
#                  so disabled)
#   :hard_breaks   single newlines will be converted to HTML break tags.
#

require 'rubygems'
require 'redcloth'

class GreenCloth < RedCloth

  # override default rules
  DEFAULT_RULES = [
    :block_crabgrass_code,
    :block_markdown_setext, 
    :block_textile_table,
    :block_textile_lists,
    :block_textile_prefix,
    :block_markdown_bq,
    :block_dictionary,
    :inline_crabgrass_link,
    :inline_auto_link_urls,
    :inline_textile_image,
    :inline_textile_code,
    :inline_textile_span,
    :glyphs_textile
  ]

  def initialize(string, default_group_name = 'page')
    @default_group = default_group_name
    super( string )
  end
  
  def to_html(*rules)
    green_html(DEFAULT_RULES)
  end
  
  # we have our own to_html method so that
  # we can insert escape_html exactly where
  # we need to in the procesessing.
  def green_html( *rules )
    rules = DEFAULT_RULES if rules.empty?
    # make our working copy
    text = self.dup
       
    @urlrefs = {}
    @shelf = []
    @rules = rules.collect do |rule|
      rule
    end.flatten

    # standard clean up
    incoming_entities text 
    clean_white_space text 

    # start processor
    @pre_list = []
    rip_offtags text, false
    #puts text
    #puts @pre_list.inspect
    escape_html text
    #no_textile text
    #hard_break text 
    unless @lite_mode
      refs text
      blocks text
    end
    inline text
    smooth_offtags text
    retrieve text

    #text.gsub!( /<\/?notextile>/, '' )
    text.gsub!( /x%x%/, '&#38;' )
    #clean_html text if filter_html
    text.strip!
    text
  end 
  
  private
  

  # makes it so that text is not filtered by any inline filters.
  # replaces the text with a placeholder, that is expanded at the end.  
  def bypass_filter( text )
    placeholder = "<redpre##{ @pre_list.length }>"
    @pre_list << text
    return placeholder
  end
  
  # disable redcloth's broken hard breaks
  def hard_break( text )
  end
  
  def green_hard_break( text )
    # redcloth original:
    text.gsub!( /(.)\n(?!\Z| *([#*=]+(\s|$)|[{|]))/, "\\1<br />" )
    
    # reading this regexp:
    # (.)         any single character
    # \n          followed by a newline
    # (?!         look ahead to the next line and fail if...
    #   \Z        the line is empty
    #   |         or
    #    *        zero or more spaces
    #   (         followed by
    #     [#*=]+  one or more #*= characters
    #     (\s|$)  and whitespace or end of line
    #     |       or 
    #     [{|]    { or | character
    #   )
    # )           end of next line expression.
  end
          
  # escape "<" when it does not in the form of <pre> or <code> or
  # </pre> or </code> or <redpre# (the latter is used internally for
  # pre blocks that are removed from the text and then put back later.
  # 
  # TODO: bluecloth/markdown actually goes through the work of parsing the html
  # to find matching tags and raises an error if a tag is not properly closed.
  # If we wanted to allow some html, it seems like a good idea to do something
  # like that.
  #
  def escape_html( text )
    text.gsub!(/<(?!\/?(redpre#|pre|code))/, "&lt;" )
  end
		
  ###############################################################3
  # INLINE FILTERS
  #
  # Here lie the greencloth inline filters. An inline filter
  # processes text within a block.
  #
  
  def xglyphs_textile( text, level = 0 )
    if text !~ HASTAG_MATCH
      pgl text
    else
      text.gsub!( ALLTAG_MATCH ) do |line|
        if $1.nil?
          glyphs_textile( line, level + 1 )
        end
        line
      end
    end
  end
  
  CRABGRASS_LINK_RE = /
    (^|.)         # start of line or any character
    \[            # begin [
    [ \t]*        # optional white space
    ([^\[\]]+)    # $text : one or more characters that are not [ or ]
    [ \t]*        # optional white space
    \]            # end ]
  /x 

  def inline_crabgrass_link( text ) 
    text.gsub!( CRABGRASS_LINK_RE ) do |m|
      preceding_char, text = $~[1..2]
      if preceding_char == '\\'
        $~[0].sub('\\[', '[').sub('\\]', ']')
      else
        # $text = "from -> to"
        from, to = text.split(/[ ]*->[ ]*/)[0..1]
        to ||= from # in case there is no "->"
        if to =~ /^(\/|https?:\/\/)/
          # assume $to is an absolute path or full url
          atts = " href=\"#{to}\""
          text = from
        else
          # $to = "group_name / page_name"
          group_name, page_name = to.split(/[ ]*\/[ ]*/)[0..1]
          unless page_name
            # there was no group indicated, so $group_name is really the $page_name
            page_name = group_name
            group_name = @default_group
          end
          text = from =~ /\// ? page_name : from
          atts = " href=\"/#{nameize group_name}/#{nameize page_name}\""
        end
        atag = bypass_filter("<a#{ atts }>#{ text }</a>")
        "#{preceding_char}#{atag}"
      end
    end
  end
  
  # eventually, it would be nice to support link titles
  # and references:
  #   atts << " title=\"#{ title }\"" if title
  #   atts = shelve( atts )  
  
  # 
  # convert text so that it is in a form that matches our 
  # convention for page names and group names:
  # - all lowercase
  # - no special characters
  # - replace spaces with hypens
  # 
  def nameize(text)
    text.strip.downcase.gsub(/[^-a-z0-9 \+]/,'').gsub(/[ ]+/,'-') if text
  end
  
  #
  # characters that might be found in a valid URL
  # according to the RFC, although some are rarely
  # seen in the wild.
  #
  # alphnum: a-z A-Z 0-9 
  #    safe: $ - _ . +
  #   extra: ! * ' ( ) ,
  #  escape: %
  #
  # additionally, the "~" character is common although expressly
  # excluded from the list of valid characters in the RFC. go figure.
  #
  
  URL_CHAR = '\w' + Regexp::quote('+%$*\'()-~')
  URL_PUNCT = Regexp::quote(',.;:!')
  
  AUTO_LINK_RE = %r{
    (                          # leading text
      <\w+.*?>|                # leading HTML tag, or
      [^=!:'"/]|               # leading punctuation, or
      ^                        # beginning of line
    )
    (
      (?:https?://)|           # protocol spec, or
      (?:www\.)                # www.*
    )
    (
      [-\w]+                   # subdomain or domain
      (?:\.[-\w]+)*            # remaining subdomains or domain
      (?::\d+)?                # port
      (?:/(?:(?:[#{URL_CHAR}]|(?:[#{URL_PUNCT}][^\s$]))+)?)* # path
      (?:\?[\w\+%&=.;-]+)?     # query string
      (?:\#[\w\-]*)?           # trailing anchor
    )
    ([[:punct:]]|\s|<|$)       # trailing text
  }x

  # 
  # auto links are extracted and put in @pre_list so they
  # can escape the inline filters.
  #                       
  def inline_auto_link_urls(text)
    text.gsub!(AUTO_LINK_RE) do
      all, a, b, c, d = $&, $1, $2, $3, $4
      if a =~ /<a\s/i # don't replace URL's that are already linked
        all
      else
        text = truncate c, 42
        url = %(#{b=="www."?"http://www.":b}#{c})
        link = bypass_filter( %(<a href="#{url}">#{text}</a>) )
        %(#{a}#{link}#{d})
      end
    end
  end
  
  # from actionview texthelper
  def truncate(text, length = 30, truncate_string = "...")
    if text.nil? then return end
    l = length - truncate_string.length
    text.length > length ? text[0...l] + truncate_string : text
  end

  #####################################################
  # BLOCK FILTERS
  #
  # Here in lie the custom GreenCloth block filters. These
  # are filters that do block level formatting, like lists
  # blockquotes, tables, etc.
 

  #
  # Dictionary entries look like this:
  # 
  # term
  #   entry one
  #   entry two
  #
  
  DICTIONARY_RE = /\A([^<\n]*)\n^( +.*)/m
  # start of string
  # title line is anything but < and \n
  # followed by definition lines that start with
  # one or more spaces 
  
  def block_dictionary( text )
    text.gsub!( DICTIONARY_RE ) do |blk|
      title = $1
      definitions = $2.gsub(/^ +(.*)$/) do |dd|
        "<dd>#{$1}</dd>"
      end
      "<dl>\n<dt>#{title}</dt>\n#{definitions}\n</dl>"
    end
  end

  def block_markdown_bq( text )
    text.gsub!( MARKDOWN_BQ_RE ) do |blk|
      blk.gsub!( /^ *> ?/, '' )
      flush_left blk
      blocks blk, false, true
      blk.gsub!( /^(\S)/, "\t\\1" ) # add two leading spaces for readability.
      "<blockquote>\n#{ blk }\n</blockquote>\n\n"
    end
  end

  # crabgrass code blocks look like this:
  #   /--
  #   here is some code
  #   \--
  # they work the same as <code>
  
  CG_CODE_BEGIN = Regexp::quote('/--')
  CG_CODE_END = Regexp::quote('\--')
  CRABGRASS_MULTI_LINE_CODE_RE = /^#{CG_CODE_BEGIN}(\s+[^\n]*)?(\n.*\n)#{CG_CODE_END}(\n|$)/m
  CRABGRASS_SINGLE_LINE_CODE_RE = /^@@( )(.*)$/
  CRABGRASS_CODE_RE = Regexp::union(CRABGRASS_MULTI_LINE_CODE_RE, CRABGRASS_SINGLE_LINE_CODE_RE)
  def block_crabgrass_code( text )
    text.gsub!( CRABGRASS_CODE_RE ) do |blk|
      body = $2||$5
      note = $1||$4
      htmlesc( body, :NoQuotes )  
      bypass_filter( format_block_code("<code #{note}>", body) )
    end
  end
    
  ######################################################
  # BLOCK PROCESSING
  #
  # The core redcloth function for block processing is blocks().
  # Unfortunately, we need to override this function, because
  # the redcloth version assumes that leading spacing in the block
  # means preformatted code. In order to change this behavior
  # we need our own blocks() function.
  #
  # So that I can understand what is going on, I have split the
  # behavior of blocks() into blocks() and process_single_block(). 
  # Some variable names have been changed to make the code more
  # readable (less inscrutable).
  #

  # Redcloth's block RE
  # BLOCKS_GROUP_RE = /\n{2,}(?! )/m
      
  def blocks(text, indented = false, in_blockquote = false) 
    text.replace( 
      text.split( BLOCKS_GROUP_RE ).collect do |blk|
        process_single_block(blk, indented, in_blockquote)
      end.join("\n\n")
    )
  end
    
  def process_single_block(blk, indented, in_blockquote)
    blk.strip!
    return "" if blk.empty?

    #debug "process block #{indented} #{in_blockquote} \n/--\n#{blk}\n\\--"
    
    # process subsequent blocks that start with
    # a leading space. if the start of this block
    # was plain, then leading spaces make the subsequent
    # blocks into an indented block.
    started_as_plain = blk !~ /\A[#*> ]/
    skip_rules_blk = nil
    blk.gsub!( /((?:\n(?:\n^ +[^\n]*)+)+)/m ) do |iblk|
      iblk_indented = true if started_as_plain
      flush_left iblk
      blocks(iblk, iblk_indented)
      #iblk.gsub( /^(\S)/, "\t\\1" )
      if iblk_indented
        # don't apply block rules to indented blocks
        skip_rules_blk = iblk; ""
      else
        iblk
      end
    end
     
    # apply block rules
    block_applied = 0 
    @rules.each do |rule_name|
      block_applied += 1 if apply_block_rule(rule_name,blk)
    end
    
    # if no rules applied and indented, then output
    # a code block, otherwise we have a plain paragraph.
    if block_applied.zero?
      if indented
        #blk = "\t<pre><code>#{ blk }</code></pre>"
        blk = "<blockquote>#{ blk }</blockquote>"
      elsif !in_blockquote
        # apply hard breaks only to plain block where no
        # block rules have applied and we are not in
        # an explicit blockquote (ie lines starting >)
        green_hard_break(blk)
        blk = "<p>#{ blk }</p>"
      else
        blk = "<p>#{ blk }</p>"
      end
    end
    # add back in text of block that bypassed block rules.
    blk + "\n#{ skip_rules_blk }"
  end

  def apply_block_rule(rule_name, blk)
    rule_name.to_s.match /^block_/ and method( rule_name ).call( blk )
  end

  ##############################################
  ## OFFTAGS: when greencloth does not apply

  # changed from redcloth values
  OFFTAGS = /(code|pre)/
  OFFTAG_MATCH = /(?:(<\/#{ OFFTAGS }>)|(<#{ OFFTAGS }[^>]*>))(.*?)(<\/?#{ OFFTAGS }>|\Z)/mi

  # rip_offtags()
  # removes 'offtags' (code that turns off processes) from the text, 
  # and replaces it with <redpre01> or <redpre02>, etc.
  # the replaced text is stored in @pre_list.
  # later, the replaced text is returned via smooth_offtags
  # comments use example string "hi <code>there</code> bigbird!"
  
  def rip_offtags( text, inline=true )
    return text unless text =~ /<.*>/ # skip unless text has the possibility of tags
    text.gsub!( OFFTAG_MATCH ) do |line|
      matchtext  = $&  # eg '<code>there</code>'
      endisfirst = $1  # eg '</code>' (only if </code> appears before <code> in the text)
      tag        = $3  # eg '<code>'
      tagname    = $4  # eg 'code'
      codebody   = $5  # eg 'there'
      if tag and codebody
        htmlesc( codebody, :NoQuotes ) #if codebody
        if inline
          line = bypass_filter( format_inline_code(tag, codebody) )
        else
          line = bypass_filter( format_block_code(tag, codebody) )
        end
      end
      line
    end
    return text
  end

  def format_inline_code(tag,body)
    tag.match /<(#{ OFFTAGS })([^>]*)>/
    tagname, args = $1, $2
    "<#{tagname}>#{body}</#{tagname}>"
  end
  
  def format_block_code(tag, body)
    tag.match /<(#{ OFFTAGS })\s*([^>]*)\s*>/
    tagname, arg = $1, $3
    ret = "<#{tagname}>#{body.strip}</#{tagname}>"
    if tagname == 'code'
      ret = "<pre class=\"code\">#{ret}</pre>"
    end
    if arg.any?
      ret = "<div class=\"#{tagname}title\">#{arg}</div>\n#{ret}"
    end
    ret
  end
  
  def debug(msg)
    if msg.is_a? Hash
      msg = msg.inspect
    end
    puts "\n====\n#{msg}\n====\n"
  end
    
end


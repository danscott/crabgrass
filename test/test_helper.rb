begin
  require 'ruby-debug'
rescue LoadError => exc
  # no ruby debug installed
end

begin
  require 'redgreen'
rescue LoadError => exc
  # no redgreen installed
end

ENV["RAILS_ENV"] = "test"
$: << File.expand_path(File.dirname(__FILE__) + "/../")
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

module Tool; end



#
# put this at the top of your test, before the class def, to see 
# the logs printed to stdout. useful for tracking what sql is called when.
# probably way too much information unless run with -n to limit the test.
# ie: ruby test/unit/page_test.rb -n test_destroy
#
def showlog
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

class Test::Unit::TestCase

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  ##########################################################################
  # Add more helper methods to be used by all tests here...

  include AuthenticatedTestHelper
  
  # make sure the associations are at least defined properly
  def check_associations(m)
    @m = m.new
    m.reflect_on_all_associations.each do |assoc|
      assert_nothing_raised("#{assoc.name} caused an error") do
        @m.send(assoc.name, true)
      end
    end
    true
  end
  
  def upload_data(file)
    type = 'image/png' if file =~ /\.png$/
    type = 'image/jpeg' if file =~ /\.jpg$/
    type = 'application/msword' if file =~ /\.doc$/
    type = 'application/octet-stream' if file =~ /\.bin$/
    fixture_file_upload('files/'+file, type)
  end

  def read_file(file)
    File.read( RAILS_ROOT + '/test/fixtures/files/' + file )
  end

=begin
  def assert_login_required(method, url)
    if method == :get
      get action, url
      assert_redirect_to {:controller => 'account', :action => 'login'}, "get %s must require a login" % url.inspect
    elsif method = :post
      post action, url
      assert_redirect_to {:controller => 'account', :action => 'login'}, "post %s must require a login" % url.inspect
    end
  end    

  def assert_login_not_required(method, url)
    if method == :get
      get action, url
      assert_response :success, {:controller => 'account', :action => 'login'}, "get %s must require a login" % url.inspect
    elsif method = :post
      post action, url
      assert_redirect_to {:controller => 'account', :action => 'login'}, "post %s must require a login" % url.inspect
    end
  end    
=end

  ##
  ## SPHINX HELPERS
  ##

  def print_sphinx_hints
    @@sphinx_hints_printed ||= false
    unless @@sphinx_hints_printed
# cg:update_page_terms
      puts "\nTo make thinking_sphinx tests not skip, try the following steps:
  rake RAILS_ENV=test db:test:prepare db:fixtures:load  # (should not be necessary, but always a good first step)
  rake RAILS_ENV=test ts:index ts:start                 # (needed to build the sphinx index and start searchd)
  rake test:functionals
See also doc/SPHINX_README"
      @@sphinx_hints_printed = true
    end

  end

  def sphinx_working?(test_name="")
    if `which searchd`.empty?
      print 'skip' #(skipping %s: sphinx not installed)' % test_name
      print_sphinx_hints
      false
    elsif !sphinx_running?
      print 'skip' #'(skipping %s: sphinx not running)' % test_name
      print_sphinx_hints
      false
    elsif !ThinkingSphinx.updates_enabled?
      print 'skip' #'(skipping %s: sphinx updated disabled)' % test_name
      print_sphinx_hints
      false
    else
      true
    end
  end

  def disable_site_testing
    Conf.disable_site_testing
    Site.current = Site.new
    @controller.disable_current_site if @controller
  end

  def enable_site_testing(site_name=nil)
    if block_given?
      enable_site_testing(site_name)
      yield
      disable_site_testing
    else
      if site_name
        Conf.enable_site_testing(sites(site_name))
        Site.current = sites(site_name) 
      else
        Conf.enable_site_testing()
        Site.current = Site.new
      end
      @controller.enable_current_site if @controller
    end
  end

  # prints out a readable version of the response. Useful when using the debugger
  def response_body
    puts @response.body.gsub(/<\/?[^>]*>/, "").split("\n").select{|str|str.strip.any?}.join("\n")
  end

end

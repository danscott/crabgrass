require File.dirname(__FILE__) + '/../test_helper'
require 'groups_controller'

# Re-raise errors caught by the controller.
class GroupsController; def rescue_action(e) raise e end; end

class GroupsControllerTest < Test::Unit::TestCase
  fixtures :groups, :users, :memberships

  include UrlHelper

  def setup
    @controller = GroupsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    login_as :gerrard
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    login_as :gerrard
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:groups)
  end

  def test_show
    login_as :blue
    get :show, :id => groups(:rainbow).name

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_get_create
    login_as :gerrard
    get :create

    assert_response :success
    assert_template 'create'
  end

  def test_create
    login_as :gerrard
    num_groups = Group.count

    post :create, :group => {:name => 'test-create-group'}

    assert_response :redirect
    group = Group.find_by_name 'test-create-group'
    assert_redirected_to url_for_group(group, :action => 'show')
    assert_equal assigns(:group).name, 'test-create-group'
    assert_equal num_groups + 1, Group.count
  end

  def test_edit
    login_as :blue
    get :edit, :id => groups(:rainbow).name

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_update
    login_as :blue
    post :update, :id => groups(:rainbow).name
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => groups(:rainbow).name
  end

  def test_destroy
#    login_as :gerrard
#    assert_not_nil Group.find(1)
#
#    post :destroy, :id => groups(:true_levellers).name
#    assert_response :redirect
#    assert_redirected_to :action => 'list'
#
#    assert_raise(ActiveRecord::RecordNotFound) {
#      Group.find(1)
#    }
  end
end

class DiscussionPageController < BasePageController

  def show
    @comment_header = ""
  end
  
  def print
    render :layout => "printer-friendly"
  end

  protected
  
  def setup_view
    @show_reply = true
    @show_attach = true
    @show_print = true
  end
  
end

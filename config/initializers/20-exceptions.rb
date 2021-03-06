# the user does not have permission to do that.
class PermissionDenied < Exception; end    

# thrown when an activerecord has made a bad association
# (for example, duplicate associations to the same object).
class AssociationError < Exception; end

# just report the error
class ErrorMessage     < Exception; end

# a list of errors with a title. oooh lala!
class ErrorMessages < Exception
  attr_accessor :title, :errors
  def initialize(title,*errors)
    self.title = title
    self.errors = errors
  end
  def to_s
    self.errors.join("\n")
  end
end

class WikiLockException < Exception; end

# extend base Exception class to have record() method.
# this is useful like so:
#
#  begin
#    @page = Page.create!( ... )
#  rescue Exception => exc
#    @page = exc.record
#    flash_message_now :exception => exc
#  end
# 
#  This way, errors can be handled by the exception, and the field in the form
#  will get little red boxes because @page is set.
#  nifty.
# 
class Exception
  def record
    nil
  end
end


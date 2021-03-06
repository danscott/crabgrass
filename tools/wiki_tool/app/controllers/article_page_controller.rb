class ArticlePageController < WikiPageController
  protected
  # called during BasePage::create
  def build_page_data
    if params[:asset][:uploaded_data].any?
      @asset = Asset.make!(params[:asset].merge(:parent_page => @page))

      raise ActiveRecord::RecordInvalid.new(@asset) unless @asset.valid?
      if @asset.thumbnail(:medium)
        image_tag = "!<%s!:%s" % [@asset.thumbnail(:medium).url, @asset.url]
      end
    end

    body = "%s\n\n%s" % [image_tag, params[:body]]
    Wiki.new(:user => current_user, :body => body)
  end

  def destroy_page_data
    super
    if @asset and !@asset.new_record?
      @asset.destroy
    end
  end
end

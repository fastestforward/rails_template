module TitleHelper
  def page_and_site_title
    if @page_title.present?
      [@page_title, site_title]
    else
      [site_title, site_slogan]
    end.compact.join(' // ')
  end

  def page_title
    @page_title
  end

  def meta_title
    if page_title.present?
      page_title
    else
      site_title
    end
  end

  def site_slogan
    "Site Slogan"
  end

  def title(text = nil)
    @page_title = text
    content_tag('h2', text)
  end

  def site_title
    "Site Title"
  end
end

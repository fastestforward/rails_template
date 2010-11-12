# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def flash_messages
    messages = "".html_safe

    [:alert, :notice].each do |type|
      if flash[type].present?
        messages << content_tag(:div, flash[type], :class => type)
      end
    end

    if messages.present?
      content_tag(:div, messages, :id => 'flash')
    end
  end

  def pluralize_with_delimiter(count, singluar, plural = nil)
    number_with_delimiter(count) + ' ' + pluralize_without_number(count, singluar, plural)
  end

  def pluralize_without_number(count, singular, plural = nil)
    count == 1 ? singular : plural || singular.pluralize
  end

  def system_status
    items = [content_tag('li', h(Rails.env.upcase + ': ' + Time.zone.now.to_s(:long_ordinal)), :class => 'overview')]

    attributes = [
      # proc returning value             # pluralizable      # link      # value class
      [proc { Delayed::Job.count },      'job',              nil,        'jobs-count'],
      [proc { User.count },              'user',             nil,        'users-count'],
      [proc { User.active.count  },      'active user',      nil,        'active-users-count'],
    ]

    if Rails.env.development?
      attributes.push([proc { RailmailDelivery.count },      'email',      '/railmail',      'emails-count'])
    end

    attributes.each do |value, countable, url, value_class|
      value =
        begin
          Timeout.timeout(0.3) { value.call } || 'X'
        rescue TimeoutError
          '?'
        rescue Exception
          '!'
        end

      contents = content_tag('span', number_with_delimiter(value), :class => "value #{value_class}") + " #{pluralize_without_number(value, countable)}"
      contents = link_to contents, url if url
      items << content_tag('li', contents)
    end

    content_tag('ul', items.to_s.html_safe, :id => 'system_status', :class => Rails.env)
  end

  # Returns a link to url with the specified content, automatically adds
  # rel="nofollow" and the external class to the link.
  def link_to_external(content, url, options = {})
    url = httpify_url(url)
    link_to content, url, options.merge(:rel => :nofollow, :class => "#{options[:class].to_s} external")
  end

  # Just like link_to_external, but uses the dehttpified url as the content.
  def link_to_external_url(url, options = {})
    link_to_external(h(dehttpify_url(url)), url, options)
  end

  # Adds http:// to a URL if missing.
  def httpify_url(url)
    if url.match(/^https?\:\/\//i)
      url
    else
      "http://#{url}"
    end
  end

  # Removes http:// from a URL if present.
  def dehttpify_url(url)
    if url.match(/^https?\:\/\//i)
      url.gsub(/^https?\:\/\//i, '')
    else
      url
    end
  end

  # Adds rel="nofollow" and auto_link class to all links by default.
  def auto_link(text, options = {}, &block)
    super(text, options.reverse_merge(:link => :all, :html => { :rel => :nofollow, :class => 'auto_link', :target => '_blank' }), &block)
  end

end

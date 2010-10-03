ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.update({
  # 4/5/9
  :mdy => proc { |t| t.strftime('%m/%d/%y').gsub /(\b)0/, '\1' },
  # Sunday, April 5, 2009
  :diary => proc { |t| t.strftime('%A, %B %e, %Y').sub(/  /, ' ') },
  # 2010-03-23 04:03PM
  :db_meridian => '%Y-%m-%d %I:%M%p',
})

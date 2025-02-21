BetterHtml.configure do |config|
  # Exclude any files not in the project directory (i.e., exclude files from
  # Gems and other external libraries.)
  config.template_exclusion_filter = proc { |filename| !filename.start_with?(Rails.root.to_s) }
end

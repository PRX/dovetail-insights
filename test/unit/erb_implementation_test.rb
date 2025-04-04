require "test_helper"

class ErbImplementationTest < ActiveSupport::TestCase
  ERB_GLOB = Rails.root.glob(
    "app/views/**/{*.htm,*.html,*.htm.erb,*.html.erb,*.html+*.erb}"
  )

  ERB_GLOB.each do |filename|
    pathname = Pathname.new(filename).relative_path_from(Rails.root)
    test "html errors in #{pathname}" do
      data = File.read(filename)
      assert_silent do
        BetterHtml::BetterErb::ErubiImplementation.new(data, filename:).validate!
      end
    end
  end
end

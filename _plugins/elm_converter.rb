# Initially based on https://github.com/sonnym/jekyll_elm
#
# USAGE:
#  Copy/paste this file into the `_plugins` directory of your Jekyll project.
#  For every .elm file in your project, it will generate a .js file in your site
#  using the same name and relative path.
#
#  As-is, the converter expects the following directory structure:
#
#      your-jekyll-project/
#      ⌞ _plugins/
#        ⌞ elm_converter.rb
#      ⌞ elm.json

require "jekyll"
require "tempfile"

class ElmConverter < Jekyll::Converter
  MODE = Jekyll.env == "development" ? "debug" : "optimize"

  safe false
  def matches(ext) ext == ".elm" end
  def output_ext(ext) ".js" end

  def convert(content)
    Tempfile.open [ "source", ".elm" ] do |source|
      Tempfile.open [ "output", ".js" ] do |output|
        File.write source.path, content
        raise unless system "cd #{@config["source"]} && \
          npx elm make #{source.path} --#{MODE} --output #{output.path}"
        output.read
      end
    end
  end
end

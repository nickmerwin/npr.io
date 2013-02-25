# _plugins/haml_converter.rb
module Jekyll
  class Layout
 
    alias old_initialize initialize
 
    def initialize(*args)
      old_initialize(*args)
      self.transform
    end
 
  end
end

module Jekyll
  require 'haml'
  class HamlConverter < Converter
    safe true
    priority :low
 
    def matches(ext)
      ext =~ /haml/i
    end
 
    def output_ext(ext)
      ".html"
    end
 
    def convert(content)
      begin
        engine = Haml::Engine.new(content)
        engine.render
      rescue Exception => e
        "#{e.message}<br/>#{e.backtrace * '<br/>'}"
      end
    end
  end
end
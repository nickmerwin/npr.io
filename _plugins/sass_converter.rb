module Jekyll
  require 'sass'
  class SassConverter < Converter
    safe true
    priority :low
 
    def matches(ext)
      puts "matches #{ext}"
      ext =~ /sass/i
    end
 
    def output_ext(ext)
      ".css"
    end
 
    def convert(content)
      begin
        puts "Performing Sass Conversion."
        engine = Sass::Engine.new(content, :syntax => :sass, :load_paths => ["./css/"])
        engine.render
      rescue StandardError => e
        puts "!!! SASS Error: " + e.message
      end
    end

  end
end

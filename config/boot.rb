# Don't change this file!
# Configure your app in config/environment.rb and config/environments/*.rb
RAILS_ROOT = "#{File.dirname(__FILE__)}/.." unless defined?(RAILS_ROOT)

module Spree
  class << self
    def boot!
      unless booted?
        preinitialize
        pick_boot.run
      end
    end

    def booted?
      defined? Spree::Initializer
    end

    def pick_boot
      (File.exist?("#{RAILS_ROOT}/lib/spree.rb") ? AppBoot : GemBoot).new
    end

    def vendor_rails?
      File.exist?("#{RAILS_ROOT}/vendor/rails")
    end

    def preinitialize
      load(preinitializer_path) if File.exist?(preinitializer_path)
    end

    def preinitializer_path
      "#{RAILS_ROOT}/config/preinitializer.rb"
    end
  end

  module RubyGemsLoader
    def load_rubygems
      require 'rubygems'

      unless rubygems_version >= '0.9.4'
        $stderr.puts %(Spree requires RubyGems >= 0.9.4 (you have #{rubygems_version}). Please `gem update --system` and try again.)
        exit 1
      end

    rescue LoadError
      $stderr.puts %(Spree requires RubyGems >= 0.9.4. Please install RubyGems and try again: http://rubygems.rubyforge.org)
      exit 1
    end
    
    def rubygems_version
      Gem::RubyGemsVersion if defined? Gem::RubyGemsVersion
    end
  end

  class Boot 
    include Spree::RubyGemsLoader
    def run
      load_rails("2.1.0") # note: spree requires a specific rails version (change at your own risk)
      load_initializer
      Spree::Initializer.run(:set_load_path)
    end
    
    def load_initializer
      begin
        require 'spree'
        require 'spree/initializer'
      rescue LoadError => e
        $stderr.puts %(Spree could not be initialized. #{load_error_message})
        exit 1
      end
    end   
    
    # since we're hijacking the initializer rails is no longer guaranteed to be available 
    # (but we need it in the initializer)
    def load_rails(version)
      if File.exist?("#{RAILS_ROOT}/vendor/rails")
        $LOAD_PATH.unshift "#{SPREE_ROOT}/vendor/rails/railties/lib"
      else
        load_rubygems
        begin
          gem 'rails', version
        rescue Gem::LoadError => load_error
          $stderr.puts %(Missing the Rails #{version} gem. Please `gem install -v=#{version} rails`.)
          exit 1
        end
      end
    end 
  end

  #class VendorBoot < Boot
  #  def load_initializer
  #    require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
  #    Spree::Initializer.run(:install_gem_spec_stubs)
  #  end
  #end

  class AppBoot < Boot
    def load_initializer
      $LOAD_PATH.unshift "#{RAILS_ROOT}/lib"
      super
    end
    
    def load_error_message
      "Please verify that you have a complete copy of the Spree sources."
    end
  end
  
  class GemBoot < Boot
    include Spree::RubyGemsLoader
    
    def load_initializer
      self.class.load_rubygems
      load_spree_gem
      require 'initializer'
    end

    def load_spre_gem
      if version = self.class.gem_version
        gem 'spree', version
      else
        gem 'spree'
      end
    rescue Gem::LoadError => load_error
      $stderr.puts %(Missing the Spree #{version} gem. Please `gem install -v=#{version} spree`, update your SPREE_GEM_VERSION setting in config/environment.rb for the Rails version you do have installed, or comment out SPREE_GEM_VERSION to use the latest version installed.)
      exit 1
    end

    class << self

      def gem_version
        if defined? SPREE_GEM_VERSION
          SPREE_GEM_VERSION
        elsif ENV.include?('SPREE_GEM_VERSION')
          ENV['SPREE_GEM_VERSION']
        else
          parse_gem_version(read_environment_rb)
        end
      end

      def load_rubygems
        require 'rubygems'

        unless rubygems_version >= '0.9.4'
          $stderr.puts %(Spree requires RubyGems >= 0.9.4 (you have #{rubygems_version}). Please `gem update --system` and try again.)
          exit 1
        end

      rescue LoadError
        $stderr.puts %(Spree requires RubyGems >= 0.9.4. Please install RubyGems and try again: http://rubygems.rubyforge.org)
        exit 1
      end

      def parse_gem_version(text)
        $1 if text =~ /^[^#]*SPREE_GEM_VERSION\s*=\s*["']([!~<>=]*\s*[\d.]+)["']/
      end

      private
        def read_environment_rb
          File.read("#{RAILS_ROOT}/config/environment.rb")
        end
    end
  end
end

# All that for this:
Spree.boot!

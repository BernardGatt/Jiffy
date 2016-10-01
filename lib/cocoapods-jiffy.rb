require 'cocoapods-jiffy/gem_version'
require 'cocoapods'

module CocoapodsJiffy
  PLATFORMS = { 'iphonesimulator' => 'iOS',
                'appletvsimulator' => 'tvOS',
                'watchsimulator' => 'watchOS' }

  PLATFORM_SYMBOL_HASH = {
                 :ios => 'iphoneos',
		 :osx => 'osx',
                 :tvos => 'appletvos',
                 :watchos => 'watchos'
	      }

  XCODE_OUTPUT=`xcodebuild -version`.lines
  BUILD_TOOLS_VERSION=XCODE_OUTPUT[0].strip + " " + XCODE_OUTPUT[1].strip.split(" ").last

    CONFIGURATIONS=['Debug', 'Release']

   @build_jiffy = ENV["BUILD_JIFFY"]
   @use_jiffy = ENV["USE_JIFFY"]

   module_function
   def build_jiffy; @build_jiffy end
   def build_jiffy= v; @build_jiffy = v end
 
   def use_jiffy; @use_jiffy end
   def use_jiffy= v; @use_jiffy = v end

end

module Pod
    class Podfile
        alias_method :_pod, :pod

        def pod(*args)
            if ! CocoapodsJiffy.build_jiffy
                _pod(*args)
            end
        end

        def cachedpod(name, *args)
            if CocoapodsJiffy.use_jiffy
            	platform = CocoapodsJiffy::PLATFORM_SYMBOL_HASH[current_target_definition.platform.name]
                for configuration in CocoapodsJiffy::CONFIGURATIONS
                   _pod "#{name}.#{configuration}", :path => File.join("Pods/#{configuration}/#{platform}/#{name}"), :integrate_target => false, :configuration => [configuration]
                end
            else
                _pod(name, *args)
            end
        end
    end
end

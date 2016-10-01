require 'fourflusher'
require 'cocoapods-jiffy'
require 'cocoapods-core/lockfile'

module CocoapodsJiffy
  def cache_dir(podspec, device, configuration, commit)
    home = ENV["HOME"]
    raise "Home doesn't exist" unless Dir.exists?(home)
    return File.join(home, ".cocoapods", "jiffy-cache", BUILD_TOOLS_VERSION, podspec, commit, device, configuration)
  end

  def build_all_configurations_for_iosish_platform(sandbox, build_dir, target, device, simulator, destination, lockfile)
    for configuration in CONFIGURATIONS
      build_for_iosish_platform(sandbox, build_dir, target, device, simulator, configuration, destination, lockfile)
    end
  end

  def build_all_configurations_for_osx(sandbox, target, destination)
    for configuration in CONFIGURATIONS
      xcodebuild(sandbox, target, 'macosx', nil, configuration)
    end 
  end

  def commit_for_pod(lockfile, pod_name)
      checkout_options = lockfile.checkout_options_for_pod_named(pod_name)
      checksum = lockfile.checksum(pod_name)
      commit = if checkout_options != nil 
    checkout_options[:commit]
      elsif checksum != nil
    checksum
      else
        raise "Commit not found for #{pod_name}" unless checkout_options != nil
      end

      return commit
  end

  def build_for_iosish_platform(sandbox, build_dir, target, device, simulator, configuration, destination, lockfile)
    deployment_target = target.platform_deployment_target
    target_label = target.cocoapods_target_label

    spec_names = target.specs.map { |spec| [spec.root.name, spec.root.module_name] }.uniq
    
    spec_names.each do |root_name, module_name|
      commit = commit_for_pod(lockfile, root_name)
      
      cache_path = cache_dir(root_name, device, configuration, commit)
      destination_for_configuration = File.join(destination, configuration, device, root_name)
      unless Dir.exists?(cache_path)
        begin
                  puts "Building #{root_name.green} - #{device.green}"
      xcodebuild(sandbox, root_name, device, deployment_target, configuration, "arm64 armv7 armv7s")
      xcodebuild(sandbox, root_name, simulator, deployment_target, configuration, "i386 x86_64")
        rescue => exception
          puts "Error building #{root_name.red}"
                puts exception.to_s
            puts exception.backtrace
        end
        executable_path = "#{build_dir}/#{root_name}"
        device_lib = "#{build_dir}/#{configuration}-#{device}/#{root_name}/#{module_name}.framework/#{module_name}"
        device_framework_lib = File.dirname(device_lib)
        simulator_lib = "#{build_dir}/#{configuration}-#{simulator}/#{root_name}/#{module_name}.framework/#{module_name}"
              simulator_framework_lib = File.dirname(simulator_lib)
              license_path = File.join(device_framework_lib, "LICENSE.md")
              podfile_path = File.join(cache_path, "#{root_name}.#{configuration}.podspec")

        next unless File.file?(device_lib) && File.file?(simulator_lib)

        lipo_log = `lipo -create -output #{executable_path} #{device_lib} #{simulator_lib}`
        puts lipo_log unless File.exist?(executable_path)

              
              #puts "FileUtils.cp_r #{simulator_framework_lib}, #{device_framework_lib}"
              FileUtils.cp_r File.join(simulator_framework_lib, "."), device_framework_lib
        FileUtils.mv executable_path, device_lib
        begin
                  FileUtils.mkdir_p cache_path
      puts "Writing dummy LICENSE.md -> #{license_path}"
      File.open(license_path, 'w') do |file|
          file.write("")
                  end
      FileUtils.cp_r device_framework_lib, cache_path, :remove_destination => true
      podspec_content = podspec_content(root_name, module_name, configuration)
        File.open(podfile_path, 'w') do |file| 
          file.write(podspec_content)
      end
        rescue
          puts "Failed to copy #{device_framework_lib} #{cache_path}"
        end
        
        #FileUtils.rm simulator_lib if File.file?(simulator_lib)
        #FileUtils.rm device_lib if File.file?(device_lib)
      else
          puts "Skipping #{root_name} - #{device}"
      end
      
      puts "Copying #{cache_path} -> #{destination_for_configuration}"
      FileUtils.mkdir_p destination_for_configuration
      FileUtils.cp_r File.join(cache_path, "."), destination_for_configuration, :remove_destination => true
    end
  end

  def xcodebuild(sandbox, target, sdk='macosx', deployment_target=nil, configuration, arch)
    puts sandbox.project_path
    args = %W(-project #{sandbox.project_path} -scheme #{target} -configuration #{configuration} -sdk #{sdk}) + ["ONLY_ACTIVE_ARCH=NO", "BITCODE_GENERATION_MODE=bitcode", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="] 
    platform = PLATFORMS[sdk]
    args += Fourflusher::SimControl.new.destination(:oldest, platform, deployment_target) unless platform.nil?
    Pod::Executable.execute_command 'xcodebuild', args, true
    #Pod::Executable.execute_command 'echo', args, true
  end

  def build_dependencies(installer_context, lockfile, sandbox, build_dir, destination)
      targets = installer_context.umbrella_targets.select { |t| t.specs.any? }
      targets.each do |target|
        puts "Processing #{target.cocoapods_target_label.green}"

        case target.platform_name
        when :ios then build_all_configurations_for_iosish_platform(sandbox, build_dir, target, 'iphoneos', 'iphonesimulator', destination, lockfile)
        when :osx then build_all_configurations_for_osx(sandbox, target.cocoapods_target_label, destination, lockfile)
        when :tvos then build_all_configurations_for_iosish_platform(sandbox, build_dir, target, 'appletvos', 'appletvsimulator', destination, lockfile)
        when :watchos then build_all_configurations_for_iosish_platform(sandbox, build_dir, target, 'watchos', 'watchsimulator', destination, lockfile)
        else raise "Unknown platform '#{target.platform_name}'" end
      end
  end

  def create_lockfile(installer_context)
    # build_dir.rmtree if build_dir.directory?
      #puts "PATH: " + sandbox_root + "/Podfile.lock"
      #puts "CLASS: " + Pod::Lockfile::from_file.
      lockfile_path = Pathname.new(installer_context.sandbox_root + "/../Podfile.lock")
      puts "PATH: " + lockfile_path.to_s# installer_context.sandbox.inspect
      lockfile = Pod::Lockfile.from_file(lockfile_path)
      puts "SANDBOX2: " + lockfile.to_s# installer_context.sandbox.inspect
      puts "SANDBOX_DATA: " + lockfile.dependencies.to_s # installer_context.sandbox.inspect
      puts "CHECKOUTS: " + lockfile.dependencies.collect { |pod| lockfile.checkout_options_for_pod_named(pod.name) }.to_s # installer_context.sandbox.inspect
      #puts "COMMITS: " + lockfile.dependencies.collect { |pod| lockfile.checkout_options_for_pod_named(pod.name)[:commit] }.to_s # installer_context.sandbox.inspect
      #pp installer_context.sandbox

      #puts "CHECKOUT SOURCES: " + installer_context.checkout_sources.inspect
      return lockfile
  end

  def podspec_content(pod_name, module_name, configuration)
    return <<-DESC
      Pod::Spec.new do |s|
      s.name             = "#{pod_name}.#{configuration}"
      s.version          = "1.0.0"
      s.summary          = "Caching podspec for #{pod_name}"
      s.description      = "Caching podspec for #{pod_name}"
      s.homepage         = "https://localhost.com/.cocoapods/cache/#{pod_name}"
      s.license          = 'MIT'
      s.author           = { "Krunoslav Zaher" => "krunoslav.zaher@gmail.com" }
      s.source           = { :path => "." }

      s.requires_arc          = true

      s.source_files          = '*.nothing'
      s.frameworks	         =  '#{module_name}'
      s.vendored_frameworks  = '#{module_name}.framework'
      end
    DESC
  end

  def post_install(installer_context)
    if ! CocoapodsJiffy.build_jiffy
      return
    end
    sandbox_root = Pathname(installer_context.sandbox_root)
    sandbox = Pod::Sandbox.new(sandbox_root)

    build_dir = sandbox_root.parent + 'build'
    destination = sandbox_root.parent + 'Pods'

    Pod::UI.puts 'Building frameworks'

    #raise Pod::Informative, 'The build directory was not found in the expected location.' unless build_dir.directory?
    
    #build_dir.rmtree if build_dir.directory?

    for configuration in CONFIGURATIONS
      destination_for_configuration = File.join(destination, configuration)
      Pod::UI.puts "Cleaning #{destination_for_configuration}"

      FileUtils.rm_r destination_for_configuration, :force => true
      FileUtils.mkdir_p destination_for_configuration
    end

    puts "SANDBOX parent: " + sandbox_root.parent.to_s

    Dir.chdir(sandbox.project_path.dirname) do
      lockfile = create_lockfile(installer_context)
      build_dependencies(installer_context, lockfile, sandbox, build_dir, destination)
      
      #puts "Copying #{cache_path} -> #{destination_for_configuration}"
      #FileUtils.mkdir_p destination_for_configuration
      #FileUtils.cp_r File.join(cache_path, "."), destination_for_configuration, :remove_destination => true
    end
  end
end

Pod::HooksManager.register('cocoapods-jiffy', :post_install) do |installer_context|
   include CocoapodsJiffy
   post_install installer_context
end

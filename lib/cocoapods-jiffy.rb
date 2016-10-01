require 'cocoapods-jiffy/gem_version'
require 'cocoapods'

module CocoapodsJiffy
  PLATFORMS = { 'iphonesimulator' => 'iOS',
                'appletvsimulator' => 'tvOS',
                'watchsimulator' => 'watchOS' }.freeze

  PLATFORM_SYMBOL_HASH = {
    ios: 'iphoneos',
    osx: 'osx',
    tvos: 'appletvos',
    watchos: 'watchos'
  }.freeze
  JIFFY_PODFILE_LOCK = 'Podfile.jiffy.lock'.freeze
  PODFILE_LOCK = 'Podfile.lock'.freeze
  XCODE_OUTPUT = `xcodebuild -version`.lines
  BUILD_TOOLS_VERSION = XCODE_OUTPUT[0].strip + ' ' + XCODE_OUTPUT[1].strip.split(' ').last

  CONFIGURATIONS = %w(Debug Release).freeze

  def self.create_lockfile(installer_context, name = PODFILE_LOCK)
    create_lockfile_for_path(installer_context.sandbox_root + "/../#{name}")
  end

  def self.create_lockfile_for_path(path)
    lockfile_path = Pathname.new(path)
    lockfile = Pod::Lockfile.from_file(lockfile_path)
    lockfile
  end
end

module CocoapodsJiffy
  @@build_jiffy = ENV['BUILD_JIFFY'].to_i == 1
  @@use_jiffy = ENV['USE_JIFFY'].to_i == 1

  @@dependencies_per_pod = nil
  @@podfile_path = nil

  def self.build_jiffy
    @@build_jiffy
  end

  def self.build_jiffy=(v)
    @@build_jiffy = v
  end

  def self.use_jiffy
    @@use_jiffy
  end

  def self.use_jiffy=(v)
    @@use_jiffy = v
  end

  def self.dependencies_per_pod
    @@dependencies_per_pod
  end

  def self.dependencies_per_pod=(v)
    @@dependencies_per_pod = v
  end

  def self.podfile_path
    @@podfile_path
  end

  def self.podfile_path=(v)
    @@podfile_path = v
  end

  def self.generate_configuration_mappings
    configuration_mappings = { 'Debug' => 'Debug', 'Release' => 'Release' }
    env_configurations = ''
    env_configurations = ENV['CONFIGURATIONS_JIFFY'] unless ENV['CONFIGURATIONS_JIFFY'].nil?
    environment_configuration_mappings = env_configurations.split(',').collect do |pair|
      parts = pair.split('=')
      result = [parts[0].strip, parts[1].strip]
      result
    end

    environment_configuration_mappings.each do |project_config, jiffy_prebuilt_config|
      configuration_mappings[project_config] = jiffy_prebuilt_config
    end
    configuration_mappings
  end

  CONFIGURATION_MAPPINGS = generate_configuration_mappings
end

module CocoapodsJiffy
  def self.collect_dependencies(name)
    dependencies = CocoapodsJiffy.dependencies_per_pod[name]
    return [name] if dependencies.nil? || dependencies.length.zero?

    all_dependencies = [[name]] + dependencies.collect do |dep|
      collect_dependencies(dep)
    end

    # exclude subspecs, we know it's a subspec if it contains "/"
    calculated_dependencies = all_dependencies.flatten.uniq.select { |x| !x.include? '/' }
    calculated_dependencies
  end

  def self.parse_name_from_name_version(name_version)
    # Pod::Spec.name_and_version_from_string(
    name_version.split(' ').first
  end

  def self.parse_dependencies(jiffy_lockfile_path)
    raise "#{jiffy_lockfile_path} is missing, please run `BUILD_JIFFY pod install` first" unless File.exist?(jiffy_lockfile_path)
    lockfile = create_lockfile_for_path(jiffy_lockfile_path)

    dependencies_per_pod = {}

    lockfile.to_hash['PODS'].each do |pod|
      pod_name_version = pod.is_a?(String) ? pod : pod.keys.first
      dependencies = []
      unless pod.is_a?(String)
        dependencies = pod.values.first.collect do |dep|
          dependency_name = parse_name_from_name_version(dep)
          dependency_name
        end
      end
      pod_name = parse_name_from_name_version(pod_name_version)
      dependencies_per_pod[pod_name] = dependencies
    end

    @@dependencies_per_pod = dependencies_per_pod
  end

  def self.ensure_podfile_jiffy_loaded(podfile_path)
    unless dependencies_per_pod.nil?
      if podfile_path != podfile_path
        raise "Podfiles differ #{podfile_path} != @{podfile_path}"
      end
      return
    end

    parse_dependencies(File.join(podfile_path.parent.to_s, JIFFY_PODFILE_LOCK))
  end

  @@cached_dependencies = []
  @@normal_dependencies = []

  def self.register_cached_dependency(dependency_name, included_as_a_dependency_of)
    @@cached_dependencies << [dependency_name, included_as_a_dependency_of]
  end

  def self.register_normal_dependency(dependency_name, included_as_a_dependency_of)
    @@normal_dependencies << [dependency_name, included_as_a_dependency_of]
  end

  def self.ensure_dependencies_exclusive
    intersection = @@cached_dependencies.collect { |x| x[0] } & @@normal_dependencies.collect { |x| x[0] }

    unless intersection.empty?
      cached_dependencies_causing_issues = @@cached_dependencies.select { |dependency_name, _| intersection.include? dependency_name } .uniq
      normal_dependencies_causing_issues = @@normal_dependencies.select { |dependency_name, _| intersection.include? dependency_name } .uniq

      extract_description = lambda do |dependency_name, included_as_a_dependency_of|
        if dependency_name == included_as_a_dependency_of
          result = "        #{dependency_name}"
        else
          result = "        #{dependency_name} included as a dependency of #{included_as_a_dependency_of}"
        end

        result
      end

      cached_dependencies_causing_issues = cached_dependencies_causing_issues.collect(&extract_description)
      normal_dependencies_causing_issues = normal_dependencies_causing_issues.collect(&extract_description)

      cached_description = " >> dependencies causing issues that were included using `cachedpod`\n" + cached_dependencies_causing_issues.join("\n")
      normal_description = " >> dependencies causing issues that were included using `pod`\n" + normal_dependencies_causing_issues.join("\n")
      raise 'Found dependencies that were included as both `cachedpod` and `pod`.' + cached_description + "\n" + normal_description
    end
  end
end

module Pod
  class Podfile
    alias _pod pod

    def pod(name, *args)
      unless CocoapodsJiffy.build_jiffy
        _pod(name, *args)
        for dependency_name in CocoapodsJiffy.collect_dependencies(name)
          CocoapodsJiffy.register_normal_dependency(dependency_name, name)
          end
      end
    end

    def cachedpod(name, *args)
      if CocoapodsJiffy.use_jiffy
        CocoapodsJiffy.ensure_podfile_jiffy_loaded(defined_in_file)

        platform = CocoapodsJiffy::PLATFORM_SYMBOL_HASH[current_target_definition.platform.name]
        dependencies = CocoapodsJiffy.collect_dependencies(name)
        for dependency_name in dependencies
          CocoapodsJiffy.register_cached_dependency(dependency_name, name)
          CocoapodsJiffy::CONFIGURATION_MAPPINGS.each do |project_configuration, jiffy_configuration|
            _pod "#{dependency_name}.#{jiffy_configuration}", path: File.join("Pods/#{jiffy_configuration}/#{platform}/#{dependency_name}"), integrate_target: false, configuration: [project_configuration]
          end
        end
      else
        _pod(name, *args)
      end
    end
  end
end

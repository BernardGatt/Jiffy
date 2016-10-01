require 'cocoapods-jiffy'

Pod::HooksManager.register('cocoapods-jiffy', :pre_install) do |installer_context|
  podfile = installer_context.podfile
  podfile.use_frameworks!
  if CocoapodsJiffy.build_jiffy
    podfile.install!('cocoapods', podfile.installation_method.last.merge(integrate_targets: false))
  end

  CocoapodsJiffy.ensure_dependencies_exclusive if CocoapodsJiffy.use_jiffy
end

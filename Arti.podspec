Pod::Spec.new do |m|

  m.name             = 'Tor'
  m.version          = '408.19.1'
  m.summary          = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description      = 'Tor.framework is the easiest way to embed Tor in your iOS application.'

  m.homepage         = 'https://github.com/iCepa/Tor.framework'
  m.license          = { :type => 'MIT', :file => 'LICENSE' }
  m.authors          = {
    'Conrad Kramer' => 'conrad@conradkramer.com',
    'Chris Ballinger' => 'chris@chatsecure.org',
    'Mike Tigas' => 'mike@tig.as',
    'Benjamin Erhart' => 'berhart@netzarchitekten.com', }
  m.source           = {
    :git => 'https://github.com/iCepa/Tor.framework.git',
    :branch => 'pure_pod',
    :tag => "v#{m.version}",
    :submodules => true }
  m.social_media_url = 'https://chaos.social/@tla'

  m.ios.deployment_target = '15.0'
  m.macos.deployment_target = '11.0'

  m.prepare_command = "Tor/download.sh v#{m.version} arti 45065181050d5c0be9032b997ebab7cedb4d9f87c9cd49e8f29a66b794599246"

  script = <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor/%1$s"
../%1$s.sh
  ENDSCRIPT

  m.subspec 'Core' do |s|
    s.requires_arc = true

    s.source_files = 'Tor/Classes/Core/**/*'
  end

  m.subspec 'Arti' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/Arti/**/*'

    s.vendored_frameworks = 'arti.xcframework'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/arti.xcframework/ios-arm64/arti.framework/Headers"',
    }

    s.preserve_paths = 'arti.xcframework', 'download.sh'

    s.user_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'USE_ARTI=1',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) USE_ARTI',
    }
  end

  m.subspec 'Onionmasq' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/Onionmasq/**/*'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Tor/onionmasq"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"onionmasq_apple"',
    }

    s.user_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'USE_ONIONMASQ=1',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) USE_ONIONMASQ',
    }

    s.script_phases = [
    {
      :name => 'Build Onionmasq',
      :execution_position => :before_compile,
      :output_files => ['onionmasq-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "onionmasq")
    },
    ]

    s.preserve_paths = 'Tor/onionmasq', 'Tor/onionmasq.sh'

  end

  m.default_subspecs = 'Arti'

end

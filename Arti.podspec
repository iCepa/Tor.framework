Pod::Spec.new do |m|

  m.name             = 'Tor'
  m.version          = '408.10.1'
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
  m.social_media_url = 'https://twitter.com/tladesignz'

  m.ios.deployment_target = '12.0'
  m.macos.deployment_target = '10.13'

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

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Tor/arti/common"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"arti_mobile_ex"',
    }

    s.user_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'USE_ARTI=1',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) USE_ARTI',
    }

    s.script_phases = [
    {
      :name => 'Build Arti',
      :execution_position => :before_compile,
      :output_files => ['arti-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "arti")
    },
    ]

    s.preserve_paths = 'Tor/arti', 'Tor/arti.sh'
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

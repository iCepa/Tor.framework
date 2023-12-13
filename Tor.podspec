Pod::Spec.new do |m|

  m.name             = 'Tor'
  m.version          = '408.10.1'
  m.summary          = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description      = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'

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

  m.subspec 'CTor' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/CTor/**/*'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Tor/tor" "${PODS_TARGET_SRCROOT}/Tor/tor/src" "${PODS_TARGET_SRCROOT}/Tor/openssl/include" "${BUILT_PRODUCTS_DIR}/openssl" "${PODS_TARGET_SRCROOT}/Tor/libevent/include"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"z" -l"lzma" -l"crypto" -l"ssl" -l"event_core" -l"event_extra" -l"event_pthreads" -l"event" -l"tor"',
    }

    s.ios.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-iOS"'
    }

    s.macos.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-macOS"'
    }

    s.script_phases = [
    {
      :name => 'Build LZMA',
      :execution_position => :before_compile,
      :output_files => ['lzma-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "xz")
    },
    {
      :name => 'Build OpenSSL',
      :execution_position => :before_compile,
      :output_files => ['openssl-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "openssl")
    },
    {
      :name => 'Build libevent',
      :execution_position => :before_compile,
      :output_files => ['libevent-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "libevent")
    },
    {
      :name => 'Build Tor',
      :execution_position => :before_compile,
      :output_files => ['tor-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "tor")
    },
    ]

    s.preserve_paths = 'Tor/include', 'Tor/libevent', 'Tor/libevent.sh', 'Tor/openssl', 'Tor/openssl.sh', 'Tor/tor', 'Tor/tor.sh', 'Tor/xz', 'Tor/xz.sh'
  end

  m.subspec 'CTor-NoLZMA' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/CTor/**/*'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Tor/tor" "${PODS_TARGET_SRCROOT}/Tor/tor/src" "${PODS_TARGET_SRCROOT}/Tor/openssl/include" "${BUILT_PRODUCTS_DIR}/openssl" "${PODS_TARGET_SRCROOT}/Tor/libevent/include"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"z" -l"crypto" -l"ssl" -l"event_core" -l"event_extra" -l"event_pthreads" -l"event" -l"tor"',
    }

    s.ios.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-iOS"'
    }

    s.macos.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-macOS"'
    }

    s.script_phases = [
    {
      :name => 'Build OpenSSL',
      :execution_position => :before_compile,
      :output_files => ['openssl-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "openssl")
    },
    {
      :name => 'Build libevent',
      :execution_position => :before_compile,
      :output_files => ['libevent-always-execute-this-but-supress-warning'],
      :script => sprintf(script, "libevent")
    },
    {
      :name => 'Build Tor',
      :execution_position => :before_compile,
      :output_files => ['tor-always-execute-this-but-supress-warning'],
      :script => <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor/tor"
../tor.sh --no-lzma
  ENDSCRIPT
    },
    ]

    s.preserve_paths = 'Tor/include', 'Tor/libevent', 'Tor/libevent.sh', 'Tor/openssl', 'Tor/openssl.sh', 'Tor/tor', 'Tor/tor.sh'
  end

  m.subspec 'GeoIP' do |s|
    s.dependency 'Tor/CTor'

    s.resource_bundles = {
      'GeoIP' => ['Tor/tor/src/config/geoip', 'Tor/tor/src/config/geoip6']
    }
  end

  m.subspec 'GeoIP-NoLZMA' do |s|
    s.dependency 'Tor/CTor-NoLZMA'

    s.resource_bundles = {
      'GeoIP' => ['Tor/tor/src/config/geoip', 'Tor/tor/src/config/geoip6']
    }
  end

  m.default_subspecs = 'CTor'

end

Pod::Spec.new do |m|

  # TODO: Why the hell do I need to provide this manually? CocoaPods should figure this out automatically, like with other pods, when they're used as static libraries.

  m.name             = 'Tor'
  m.version          = '408.4.1'
  m.summary          = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description      = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'

  m.homepage         = 'https://github.com/iCepa/Tor.framework'
  m.license          = { :type => 'MIT', :file => 'LICENSE' }
  m.authors          = { 'Conrad Kramer' => 'conrad@conradkramer.com',
                         'Chris Ballinger' => 'chris@chatsecure.org',
                         'Mike Tigas' => 'mike@tig.as',
                         'Benjamin Erhart' => 'berhart@netzarchitekten.com', }
  m.source           = { :git => 'https://github.com/iCepa/Tor.framework.git',
                         :branch => 'pure_pod',
                         :tag => "v#{m.version}",
                         :submodules => true }
  m.social_media_url = 'https://twitter.com/tladesignz'

  m.ios.deployment_target = '11.0'
  m.macos.deployment_target = '10.13'

  m.subspec 'Core' do |s|
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Tor/tor" "${PODS_TARGET_SRCROOT}/Tor/tor/src" "${PODS_TARGET_SRCROOT}/Tor/openssl/include"   "${BUILT_PRODUCTS_DIR}/openssl" "${PODS_TARGET_SRCROOT}/Tor/libevent/include"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"z" -l"lzma" -l"crypto" -l"ssl" -l"event_core" -l"event_extra" -l"event_pthreads" -l"event" -l"tor"'
    }

    s.ios.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-iOS"'
    }

    s.macos.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-macOS"'
    }

    s.user_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/Headers/Public"',
      'OTHER_LDFLAGS' => '$(inherited) -l"z" -l"lzma" -l"crypto" -l"ssl" -l"event_core" -l"event_extra" -l"event_pthreads" -l"event" -l"tor"'
    }

    script = <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor/%1$s"
../%1$s.sh
ENDSCRIPT

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
      {
        :name => 'Link Headers',
        :execution_position => :before_compile,
        :output_files => ['headers-always-execute-this-but-supress-warning'],
        :script => <<-ENDSCRIPT
mkdir -p "${PODS_ROOT}/Headers/Public/Tor"
cd "${PODS_ROOT}/Headers/Public/Tor"
find "${PODS_TARGET_SRCROOT}/Tor/Classes" -name "*.h" -maxdepth 1 -exec ln -s {} \\;
ENDSCRIPT
      }
    ]

    s.requires_arc = true

    s.source_files = 'Tor/Classes/**/*'

    s.preserve_paths = 'Tor/include', 'Tor/libevent', 'Tor/libevent.sh', 'Tor/openssl', 'Tor/openssl.sh', 'Tor/tor', 'Tor/tor.sh', 'Tor/xz', 'Tor/xz.sh'
  end

  m.subspec 'GeoIP' do |s|
    s.dependency 'Tor/Core'

    s.resource_bundles = {
      'GeoIP' => ['Tor/tor/src/config/geoip', 'Tor/tor/src/config/geoip6']
    }
  end

  m.default_subspecs = 'Core'

end

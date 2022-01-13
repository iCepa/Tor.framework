Pod::Spec.new do |m|

  tor_version = '0.4.6.8'

  m.name             = 'Tor'
  m.version          = '406.8.2'
  m.summary          = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description      = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'

  m.homepage         = 'https://github.com/iCepa/Tor.framework'
  m.license          = { :type => 'MIT', :file => 'LICENSE' }
  m.authors          = { 'Conrad Kramer' => 'conrad@conradkramer.com',
                         'Chris Ballinger' => 'chris@chatsecure.org',
                         'Mike Tigas' => 'mike@tig.as',
                         'Benjamin Erhart' => 'berhart@netzarchitekten.com', }
  m.source           = { :git => '"https://github.com/iCepa/Tor.framework.git', :tag => m.version.to_s }
  m.social_media_url = 'https://twitter.com/tladesignz'

  m.ios.deployment_target = '9.0'
  m.macos.deployment_target = '10.9'

  m.prepare_command = <<-ENDSCRIPT
touch geoip
touch geoip6
ENDSCRIPT

  m.subspec 'Core' do |s|
    s.xcconfig = {
      'APPLICATION_EXTENSION_API_ONLY' => 'YES',
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/Tor/tor" "${PODS_TARGET_SRCROOT}/Tor/tor/src" "${PODS_TARGET_SRCROOT}/Tor/openssl/include" "${PODS_TARGET_SRCROOT}/Tor/libevent/include"',
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor" -l"z" -l"lzma" -l"crypto" -l"ssl" -l"event_core" -l"event_extra" -l"event_pthreads" -l"event" -l"tor"'
    }

    s.ios.xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-iOS"'
    }

    s.macos.xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -L"${BUILT_PRODUCTS_DIR}/Tor-macOS"'
    }

    s.script_phases = [
      {
        :name => 'Build XZ',
        :execution_position => :before_compile,
        :script => <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor"

if [ ! -d xz ]
then
  git clone --branch v5.2.5 --single-branch --recurse-submodules https://git.tukaani.org/xz.git
fi

cd xz

../xz.sh
ENDSCRIPT
      },
      {
        :name => 'Build OpenSSL',
        :execution_position => :before_compile,
        :script => <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor"

if [ ! -d openssl ]
then
  git clone --branch OpenSSL_1_1_1m --single-branch --recurse-submodules https://github.com/openssl/openssl.git
fi

cd openssl

../openssl.sh
ENDSCRIPT
      },
      {
        :name => 'Build libevent',
        :execution_position => :before_compile,
        :script => <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor"

if [ ! -d libevent ]
then
  git clone --branch release-2.1.12-stable --single-branch --recurse-submodules https://github.com/libevent/libevent.git
fi

cd libevent

../libevent.sh
ENDSCRIPT
      },
      {
        :name => 'Build Tor',
        :execution_position => :before_compile,
        :script => <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor"

if [ ! -d tor ]
then
  git clone --branch tor-0.4.6.9 --single-branch --recurse-submodules https://git.torproject.org/tor.git
fi

cd tor

../tor.sh
ENDSCRIPT
      },
    ]

    s.requires_arc = true

    s.source_files = 'Tor/Classes/**/*'
  end

  m.subspec 'GeoIP' do |s|
    s.dependency 'Tor/Core'

    s.script_phase = {
      :name => 'Load GeoIP files',
      :execution_position => :before_compile,
      :script => <<-ENDSCRIPT
      if [ ! -f "$PODS_TARGET_SRCROOT/geoip" ] || \
          test `find "$PODS_TARGET_SRCROOT" -name geoip -empty` || \
          test `find "$PODS_TARGET_SRCROOT" -name geoip -mtime +1`
      then
        curl -Lo "$PODS_TARGET_SRCROOT/geoip" https://gitweb.torproject.org/tor.git/plain/src/config/geoip?h=tor-#{tor_version}
      fi

      if [ ! -f "$PODS_TARGET_SRCROOT/geoip6" ] || \
          test `find "$PODS_TARGET_SRCROOT" -name geoip6 -empty` || \
          test `find "$PODS_TARGET_SRCROOT" -name geoip6 -mtime +1`
      then
        curl -Lo "$PODS_TARGET_SRCROOT/geoip6" https://gitweb.torproject.org/tor.git/plain/src/config/geoip6?h=tor-#{tor_version}
      fi
      ENDSCRIPT
    }

    s.resource_bundles = {
      'GeoIP' => ['geoip', 'geoip6']
    }
  end

  m.default_subspecs = 'Core'

end

Pod::Spec.new do |m|

  tor_version = 'tor-0.4.6.9'
  xz_version = 'v5.2.5'
  openssl_version = 'OpenSSL_1_1_1m'
  libevent_version = 'release-2.1.12-stable'

  m.name             = 'Tor'
  m.version          = '406.9.1'
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

    script = <<-ENDSCRIPT
cd "${PODS_TARGET_SRCROOT}/Tor"

if [ -d %1$s ] && [ ! `find . -name %1$s -empty` ]
then
  cd %1$s
  rm -rf *
  git checkout %2$s > /dev/null
  git restore .
  git submodule update --init --recursive
else
  git clone --branch %2$s --single-branch --recurse-submodules %3$s
  cd %1$s
fi

../%1$s.sh
ENDSCRIPT

    s.script_phases = [
      {
        :name => 'Build XZ',
        :execution_position => :before_compile,
        :script => sprintf(script, "xz", xz_version, "https://git.tukaani.org/xz.git")
      },
      {
        :name => 'Build OpenSSL',
        :execution_position => :before_compile,
        :script => sprintf(script, "openssl", openssl_version, "https://github.com/openssl/openssl.git")
      },
      {
        :name => 'Build libevent',
        :execution_position => :before_compile,
        :script => sprintf(script, "libevent", libevent_version, "https://github.com/libevent/libevent.git")
      },
      {
        :name => 'Build Tor',
        :execution_position => :before_compile,
        :script => sprintf(script, "tor", tor_version, "https://git.torproject.org/tor.git")
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
cd "${PODS_TARGET_SRCROOT}"
if [ ! -f geoip ] || [ `find . -name geoip -empty` ] || [ `find . -name geoip -mtime +1` ]
then
  curl -Lo geoip https://gitweb.torproject.org/tor.git/plain/src/config/geoip?h=#{tor_version}
fi

if [ ! -f geoip6 ] || [ `find . -name geoip6 -empty` ] || [ `find . -name geoip6 -mtime +1` ]
then
  curl -Lo geoip6 https://gitweb.torproject.org/tor.git/plain/src/config/geoip6?h=#{tor_version}
fi
ENDSCRIPT
    }

    s.resource_bundles = {
      'GeoIP' => ['geoip', 'geoip6']
    }
  end

  m.default_subspecs = 'Core'

end

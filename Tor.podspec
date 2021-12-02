Pod::Spec.new do |m|

  tor_version = '0.4.6.8'

  m.name    = 'Tor'
  m.version = '406.8.2'

  m.summary     = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'
  m.homepage    = 'https://github.com/iCepa/Tor.framework'
  m.license     = { :type => 'MIT' }
  m.authors     = { 'Conrad Kramer' => 'conrad@conradkramer.com',
                    'Chris Ballinger' => 'chris@chatsecure.org',
                    'Mike Tigas' => 'mike@tig.as',
                    'Benjamin Erhart' => 'berhart@netzarchitekten.com', }

  m.source = {
    :http => "https://github.com/iCepa/Tor.framework/releases/download/v#{m.version}/Tor.framework.zip",
    :flatten => true
  }

  m.ios.deployment_target = '9.0'
  m.osx.deployment_target = '10.9'

  m.module_name = 'Tor'

  m.subspec 'Core' do |s|
      s.requires_arc = true

      s.ios.vendored_frameworks = 'Build/iOS/Tor.framework'
      s.osx.vendored_frameworks = 'Build/Mac/Tor.framework'

      s.preserve_path = '**/*.bcsymbolmap'
  end

  m.prepare_command = <<-SCRIPT
  touch geoip
  touch geoip6
  SCRIPT

  m.subspec 'GeoIP' do |s|
    s.dependency 'Tor/Core'

    s.script_phase = {
      :name => 'Load GeoIP files',
      :execution_position => :before_compile,
      :script => <<-SCRIPT
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
      SCRIPT
    }

    s.resource_bundles = {
      'GeoIP' => ['geoip', 'geoip6']
    }
  end

  m.default_subspecs = 'Core'

end

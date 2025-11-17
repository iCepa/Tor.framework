Pod::Spec.new do |m|

  m.name             = 'Tor'
  m.version          = '408.20.1'
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
    :tag => "v#{m.version}" }
  m.social_media_url = 'https://chaos.social/@tla'

  m.ios.deployment_target = '15.0'
  m.macos.deployment_target = '11.0'

  m.prepare_command = "Tor/download.sh v#{m.version} c3908860219b39fca73f3d9a890f290c92c74fd720e537c40777f5d992300a4c 6e297b5e4f153824b17ffbcabd95f67c8aa13420fb6de9a6563096459c668f1a"

  m.subspec 'Core' do |s|
    s.requires_arc = true

    s.source_files = 'Tor/Classes/Core/**/*'
  end

  m.subspec 'CTor' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/CTor/**/*'

    s.vendored_frameworks = 'tor.xcframework'
    s.libraries = 'z'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/tor.xcframework/ios-arm64/tor.framework/Headers"',
    }

    s.preserve_paths = 'tor.xcframework', 'download.sh'
  end

  m.subspec 'CTor-NoLZMA' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/CTor/**/*'

    s.vendored_frameworks = 'tor-nolzma.xcframework'
    s.libraries = 'z'

    s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/tor-nolzma.xcframework/ios-arm64/tor-nolzma.framework/Headers"',
    }

    s.preserve_paths = 'tor-nolzma.xcframework', 'Tor/download.sh'
  end

  m.subspec 'GeoIP' do |s|
    s.dependency 'Tor/CTor'

    s.resource_bundles = {
      'GeoIP' => ['Tor/Assets/geoip', 'Tor/Assets/geoip6']
    }
  end

  m.subspec 'GeoIP-NoLZMA' do |s|
    s.dependency 'Tor/CTor-NoLZMA'

    s.resource_bundles = {
      'GeoIP' => ['Tor/Assets/geoip', 'Tor/Assets/geoip6']
    }
  end

  m.default_subspecs = 'CTor'

end

Pod::Spec.new do |m|

  m.name             = 'Tor'
  m.version          = '409.11.1'
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

  m.prepare_command = "Tor/download.sh v#{m.version} \"tor tor-nolzma\" 80711b4f831a0de8128038c044da07afabca32ccc7ee7affaddbbd2e3e313196 8c2b0ae078e89e1aaab2d5310fe2d19eed7d6a249c6fd6bcf7e8caf9435e19f1"

  m.subspec 'Core' do |s|
    s.requires_arc = true

    s.source_files = 'Sources/TorCore/**/*'
  end

  m.subspec 'CTor' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Sources/CTor/**/*'

    s.vendored_frameworks = 'tor.xcframework'
    s.libraries = 'z'


    s.preserve_paths = 'tor.xcframework', 'download.sh'
  end

  m.subspec 'CTor-NoLZMA' do |s|
    s.dependency 'Tor/Core'

    s.source_files = 'Tor/Classes/CTor/**/*'

    s.vendored_frameworks = 'tor-nolzma.xcframework'
    s.libraries = 'z'


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

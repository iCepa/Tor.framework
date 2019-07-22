Pod::Spec.new do |m|

  version = '400.5.2'

  m.name    = 'Tor'
  m.version = version

  m.summary     = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'
  m.homepage    = 'https://github.com/iCepa/Tor.framework'
  m.license     = { :type => 'MIT', :file => 'LICENSE' }
  m.authors     = { 'Conrad Kramer' => 'conrad@conradkramer.com',
                    'Chris Ballinger' => 'chris@chatsecure.org',
                    'Mike Tigas' => 'mike@tig.as',
                    'Benjamin Erhart' => 'berhart@netzarchitekten.com', }

  m.source = {
    :http => "https://github.com/iCepa/Tor.framework/releases/download/v#{m.version.to_s}/Tor.framework.zip",
    :flatten => true
  }

  m.ios.deployment_target = '9.0'
  m.osx.deployment_target = '10.9'

  m.requires_arc = true

  m.ios.vendored_frameworks = 'Build/iOS/Tor.framework'
  m.osx.vendored_frameworks = 'Build/Mac/Tor.framework'
  m.module_name = 'Tor'

  m.preserve_path = '**/*.bcsymbolmap'

end

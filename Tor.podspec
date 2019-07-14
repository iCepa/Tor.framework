Pod::Spec.new do |m|

  version = '400.5.1'

  m.name    = 'Tor'
  m.version = version

  m.summary           = 'Tor.framework is the easiest way to embed Tor in your iOS application.'
  m.description       = 'Tor.framework is the easiest way to embed Tor in your iOS application. Currently, the framework compiles in static versions of tor, libevent, openssl, and liblzma.'
  m.homepage          = 'https://github.com/iCepa/Tor.framework'
  m.license      = { :type => 'MIT', :text => <<-LICENSE
    Copyright (c) 2015-2017 Conrad Kramer (https://conradkramer.com)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
    LICENSE
  }
  m.authors = { 'Chris Ballinger' => 'chris@chatsecure.org',
                'Conrad Kramer' => 'conrad@conradkramer.com' }

  m.source = {
    :http => "https://github.com/iCepa/Tor.framework/releases/download/v#{m.version.to_s}/Tor.framework.zip",
    :flatten => true
  }

  m.platform              = :ios
  m.ios.deployment_target = '9.0'

  m.requires_arc = true

  m.vendored_frameworks = 'Build/iOS/Tor.framework'
  m.module_name = 'Tor'

  m.preserve_path = '**/*.bcsymbolmap'

end
Pod::Spec.new do |s|
  s.name             = 'knowme_vpn_native'
  s.version          = '1.0.0'
  s.summary          = 'KNOWME VPN iOS native bridge'
  s.description      = 'Starts and stops the WireGuard packet tunnel extension.'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'KNOWME' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'NetworkExtension'
  s.swift_version    = '5.0'
end

Pod::Spec.new do |s|
  s.name             = 'impulse_player_ios'
  s.version          = '0.1.0'
  s.summary          = 'Impulse Player iOS plugin'
  s.description      = <<-DESC
Impulse Player iOS.
                       DESC
  s.homepage         = 'http://getimpulse.io'
  s.license          = { :file => 'LICENSE' }
  s.author           = { 'Webuildapps' => 'info@webuildapps.com' }
  s.source           = { :path => '.' }
  s.module_name = "ImpulsePlayer"
  s.source_files = 'Sources/**/*.swift'
  s.resources = "Sources/Resources/*"
  
  s.platform = :ios, '14.0'
end

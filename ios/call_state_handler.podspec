Pod::Spec.new do |s|
  s.name             = 'call_state_handler'
  s.version          = '3.0.0'
  s.summary          = 'A Flutter plugin to detect phone calls'
  s.description      = <<-DESC
A Flutter plugin that detects when phone calls are active. Uses CallKit and CoreTelephony.
                       DESC
  s.homepage         = 'https://github.com/Abdusamad98/call_state_handler'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Abdusamad'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'CallKit', 'CoreTelephony'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end

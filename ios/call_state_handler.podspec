Pod::Spec.new do |s|
  s.name             = 'call_state_handler'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin to detect phone and video calls'
  s.description      = <<-DESC
A Flutter plugin that detects when phone calls and video calls are active.
                       DESC
  s.homepage         = 'https://github.com/yourusername/call_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
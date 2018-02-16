Pod::Spec.new do |s|
  s.name             = "SPCamera"
  s.summary          = "Simple Camera framework which only takes still photos. No Live Photo or Videos currently."
  s.version          = "0.3.0"
  s.homepage         = "https://github.com/spint01/SPCamera"
  s.license          = 'Copyright SGP Enterprises, Inc.'
  s.author           = { "SGP Enterprises, Inc." => "steve.pint@gmail.com" }
  s.source           = { :git => "https://github.com/spint01/SPCamera.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/spint01'
  s.platform         = :ios, '10.0'
  s.requires_arc     = true
  s.source_files     = 'Source/**/*'
  # s.resource_bundles = { 'ImagePicker' => ['Images/*.{png}'] }
  s.frameworks       = 'AVFoundation'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.0' }
end

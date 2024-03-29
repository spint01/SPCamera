Pod::Spec.new do |s|
  s.name             = "SPCamera"
  s.summary          = "Simple Camera framework which only takes still photos. No Live Photos. Videos in Beta testing."
  s.version          = "1.0.5"
  s.homepage         = "https://github.com/spint01/SPCamera"
  s.license          = 'Copyright SGP Enterprises, Inc.'
  s.author           = { "SGP Enterprises, Inc." => "steve.pint@gmail.com" }
  s.source           = { :git => "https://github.com/spint01/SPCamera.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/spint01'
  s.platform         = :ios, '13.0'
  s.requires_arc     = true
  s.source_files     = 'Sources/SPCamera/**/*'
  s.resource_bundles = { 'SPCamera' => ['Images/*.{png}'] }
  s.frameworks       = 'AVFoundation'
  s.swift_version    = "5.0"
  s.ios.deployment_target = "13.0"
end

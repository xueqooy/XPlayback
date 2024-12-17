#
# Be sure to run `pod lib lint Playback.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Playback'
  s.version          = '0.1.0'
  s.summary          = 'A short description of Video Playback.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/xuejianhui/Playback'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'xuejianhui' => '106154926+xue-nd@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/xuejianhui/Playback.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'

  s.static_framework = true
  
  s.source_files = 'Source/Playback/**/*.{h,m,swift}'
  
  s.resource_bundles = {
    'Playback_Assets' => ['Source/Playback/*.xcassets'],
  }

  s.dependency 'PlaybackFoundation'
  s.dependency 'XUI'
  s.dependency 'XKit'
  
end

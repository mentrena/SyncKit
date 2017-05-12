#
# Be sure to run `pod lib lint SyncKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SyncKit'
  s.version          = '0.4'
  s.summary          = 'CloudKit synchronization for your Core Data model.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
SyncKit automates the process of synchronizing your Core Data models using CloudKit. It can easily be plugged into (and removed from) your existing stack.
                       DESC

  s.homepage         = 'https://github.com/mentrena/SyncKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Entrena' => 'manuel@mentrena.com' }
  s.source           = { :git => 'https://github.com/mentrena/SyncKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

s.ios.deployment_target = '8.0'
s.osx.deployment_target = '10.11'

	s.subspec 'CoreData' do |cs|
		cs.public_header_files = 'SyncKit/Classes/QSSynchronizer/*.h', 'SyncKit/Classes/CoreData/*.h'
		cs.source_files = 'SyncKit/Classes/QSSynchronizer/*.{h,m}', 'SyncKit/Classes/CoreData/*.{h,m}'
		cs.resources = 'SyncKit/Classes/CoreData/*.xcdatamodeld'
		cs.frameworks = 'CoreData', 'CloudKit'
	end
	
	s.subspec 'Realm' do |cs|
		cs.public_header_files = 'SyncKit/Classes/QSSynchronizer/*.h', 'SyncKit/Classes/Realm/*.h'
		cs.source_files = 'SyncKit/Classes/QSSynchronizer/*.{h,m}', 'SyncKit/Classes/Realm/*.{h,m}'
		cs.frameworks = 'CloudKit'
		cs.dependency 'Realm'
	end

  # s.resource_bundles = {
  #   'SyncKit' => ['SyncKit/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end

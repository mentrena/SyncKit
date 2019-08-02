#
# Be sure to run `pod lib lint SyncKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SyncKit'
 s.version          = '0.7.5'
  s.summary          = 'CloudKit synchronization for your Core Data or Realm model.'

  s.description      = <<-DESC
SyncKit automates the process of synchronizing your Core Data/Realm models using CloudKit. It can easily be plugged into (and removed from) your existing stack.
                       DESC

  s.homepage         = 'https://github.com/mentrena/SyncKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Manuel Entrena' => 'manuel@mentrena.com' }
  s.source           = { :git => 'https://github.com/mentrena/SyncKit.git', :tag => s.version.to_s }
  s.swift_version    = '5.0'
  s.module_name		 = 'SyncKit'

s.ios.deployment_target = '10.0'
s.osx.deployment_target = '10.12'
s.watchos.deployment_target = '3.0'

s.default_subspec = 'Core'

s.subspec 'Core' do |cs|
	cs.source_files = 'SyncKit/Classes/QSSynchronizer/*.swift', 'SyncKit/Classes/QSSynchronizer/Operations/*.swift'
	cs.frameworks = 'CloudKit'
end

s.subspec 'CoreData' do |cs|
	cs.dependency 'SyncKit/Core'
	cs.source_files = 'SyncKit/Classes/CoreData/*.swift'
	cs.preserve_paths = 'SyncKit/Classes/CoreData/*.xcdatamodeld'
	cs.resources = 'SyncKit/Classes/CoreData/*.xcdatamodeld'
	cs.frameworks = 'CoreData'
end
	
s.subspec 'Realm' do |cs|
	cs.dependency 'SyncKit/Core'
	cs.dependency 'Realm', '~> 3.0'
	cs.source_files = 'SyncKit/Classes/Realm/*.swift'
end

s.subspec 'RealmSwift' do |cs|
	cs.dependency 'SyncKit/Core'
	cs.dependency 'RealmSwift', '~> 3.0'
	cs.source_files = 'SyncKit/Classes/RealmSwift/*.swift'
end

end

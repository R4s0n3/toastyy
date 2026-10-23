#!/usr/bin/env ruby
# Maintainer utility. The generated project is checked in; users need only Xcode.
# gem install xcodeproj -v 1.28.1
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent
project = Xcodeproj::Project.new((root + 'Toastyy.xcodeproj').to_s)
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.compatibility_version = 'Xcode 14.0'

app = project.new_target(:application, 'Toastyy', :ios, '17.0')
tests = project.new_target(:ui_test_bundle, 'ToastyyUITests', :ios, '17.0')
tests.add_dependency(app)
project.root_object.attributes['TargetAttributes'] = {
  tests.uuid => {'TestTargetID' => app.uuid},
  app.uuid => {'CreatedOnToolsVersion' => '16.0'}
}

group = project.main_group.new_group('Toastyy', 'Toastyy')
%w[App Scene Views].each do |directory|
  child = group.new_group(directory, directory)
  Dir.glob((root + "Toastyy/#{directory}/*.swift").to_s).sort.each do |source|
    app.source_build_phase.add_file_reference(child.new_file(File.basename(source)))
  end
end
group.new_file('Info.plist')
resources = group.new_group('Resources', 'Resources')
%w[Toaster.usdz PrivacyInfo.xcprivacy Assets.xcassets].each do |file|
  ref = resources.new_file(file)
  app.resources_build_phase.add_file_reference(ref)
end
resources.new_file('Toaster.provenance.json')

test_group = project.main_group.new_group('ToastyyUITests', 'ToastyyUITests')
tests.source_build_phase.add_file_reference(test_group.new_file('ToastyyUITests.swift'))

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = '.'
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'ToastyyCore'
app.package_product_dependencies << product
link = project.new(Xcodeproj::Project::Object::PBXBuildFile)
link.product_ref = product
app.frameworks_build_phase.files << link

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end
app.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.toastyy.app',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'Toastyy/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'MARKETING_VERSION' => '1.0.0',
    'CURRENT_PROJECT_VERSION' => '1',
    'CODE_SIGN_STYLE' => 'Automatic',
    'TARGETED_DEVICE_FAMILY' => '1',
    'SUPPORTS_MACCATALYST' => 'NO',
    'SUPPORTED_PLATFORMS' => 'iphoneos iphonesimulator',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_STRICT_CONCURRENCY' => 'targeted'
  })
end
tests.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.toastyy.app.uitests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'TEST_TARGET_NAME' => 'Toastyy',
    'TARGETED_DEVICE_FAMILY' => '1',
    'CODE_SIGN_STYLE' => 'Automatic',
    'SWIFT_STRICT_CONCURRENCY' => 'targeted'
  })
end

# xcodeproj's default framework reference contains its newest SDK version.
# Resolve against the selected SDK instead, including Simulator SDKs and Xcode 16.
project.files.select { |file| file.path&.end_with?('/Foundation.framework') }.each do |file|
  file.source_tree = 'SDKROOT'
  file.path = 'System/Library/Frameworks/Foundation.framework'
end

project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(tests, false)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as((root + 'Toastyy.xcodeproj').to_s, 'Toastyy', true)
puts 'Generated Toastyy.xcodeproj with shared Toastyy scheme.'

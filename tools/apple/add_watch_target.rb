#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the Apple Watch app (apple/TibyanWatch) to ios/Runner.xcodeproj as
# its own watchOS target, signed automatically with the Tibyan team, with
# its app icon and the app's version (ios/Flutter/Watch.xcconfig). With
# --embed it is also embedded in Runner. Running it again only re-applies
# these settings.
#
#   gem install xcodeproj
#   ruby tools/apple/add_watch_target.rb          # add the target
#   ruby tools/apple/add_watch_target.rb --embed  # also embed it in Runner
#
# Check it builds:
#   xcodebuild -project ios/Runner.xcodeproj -target TibyanWatch \
#     -sdk watchsimulator CODE_SIGNING_ALLOWED=NO build

require 'xcodeproj'

Encoding.default_external = Encoding::UTF_8

NAME = 'TibyanWatch'
BUNDLE = 'app.tibyan.tibyan.watchkitapp'
DEPLOYMENT = '10.0'

root = File.expand_path('../..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios', 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'

WIDGET_NAME = 'TibyanWatchWidgets'
WIDGET_BUNDLE = "#{BUNDLE}.widgets"

target = project.targets.find { |t| t.name == NAME }
apple = project.main_group['Apple'] || project.main_group.new_group('Apple', '../apple')
group = apple[NAME] || apple.new_group(NAME, NAME)
strings = group['Localizable.strings'] || group.new_variant_group('Localizable.strings')
%w[ar en].each do |lang|
  unless strings.files.any? { |f| f.name == lang }
    ref = strings.new_reference("#{lang}.lproj/Localizable.strings")
    ref.name = lang
    ref.last_known_file_type = 'text.plist.strings'
  end
end

unless target
  target = project.new_target(:application, NAME, :watchos, DEPLOYMENT, nil, :swift)
  sources = %w[TibyanWatchApp.swift WatchStore.swift].map { |f| group[f] || group.new_reference(f) }
  target.add_file_references(sources)
  target.add_resources([strings])
  target.add_system_framework(%w[WatchConnectivity SwiftUI WidgetKit])

  target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['SDKROOT'] = 'watchos'
    s['WATCHOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
    s['TARGETED_DEVICE_FAMILY'] = '4'
    s['SWIFT_VERSION'] = '5.0'
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['INFOPLIST_KEY_CFBundleDisplayName'] = 'تبيان'
    s['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'
    s['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown'
    s['SKIP_INSTALL'] = 'YES'
    s['DEVELOPMENT_ASSET_PATHS'] = ''
    s['LOCALIZATION_PREFERS_STRING_CATALOGS'] = 'NO'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  end
end

target.add_system_framework(%w[WidgetKit])

widget_target = project.targets.find { |t| t.name == WIDGET_NAME }
unless widget_target
  widget_target = project.new_target(:app_extension, WIDGET_NAME, :watchos, DEPLOYMENT, nil, :swift)
  widget_source = group['TibyanWatchWidgets.swift'] || group.new_reference('TibyanWatchWidgets.swift')
  widget_target.add_file_references([widget_source])
  widget_target.add_resources([strings])
  widget_target.add_system_framework(%w[WidgetKit SwiftUI])

  widget_target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['SDKROOT'] = 'watchos'
    s['WATCHOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
    s['TARGETED_DEVICE_FAMILY'] = '4'
    s['SWIFT_VERSION'] = '5.0'
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['INFOPLIST_KEY_CFBundleDisplayName'] = 'الختمة'
    s['SKIP_INSTALL'] = 'YES'
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    s['LOCALIZATION_PREFERS_STRING_CATALOGS'] = 'NO'
    s['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks'
    ]
  end

  target.add_dependency(widget_target)
  embed_widgets = target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } ||
                  target.new_copy_files_build_phase('Embed App Extensions')
  embed_widgets.symbol_dst_subfolder_spec = :plug_ins
  unless embed_widgets.files_references.include?(widget_target.product_reference)
    file = embed_widgets.add_file_reference(widget_target.product_reference, true)
    file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }
  end
end

if ARGV.include?('--embed')
  # Only now does it name its companion: Flutter treats a project with a
  # watch companion differently (simulator builds then need `-d <id>`).
  target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'app.tibyan.tibyan'
  end
  embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' } ||
          runner.new_copy_files_build_phase('Embed Watch Content')
  embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  embed.symbol_dst_subfolder_spec = :products_directory
  unless embed.files_references.include?(target.product_reference)
    runner.add_dependency(target)
    file = embed.add_file_reference(target.product_reference, true)
    file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }
  end
  # As for the widgets: embedding runs before Flutter's "Thin Binary".
  thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  if thin && runner.build_phases.index(embed) > runner.build_phases.index(thin)
    runner.build_phases.delete(embed)
    runner.build_phases.insert(runner.build_phases.index(thin), embed)
  end
end

# The watch app's Arabic strings.
regions = project.root_object.known_regions
regions << 'ar' unless regions.include?('ar')

# Applied on every run (also to targets added by older versions of this script).
TEAM = 'T958VWM76Z'
xcconfig = project.main_group['Flutter'].files.find { |f| f.path == 'Flutter/Watch.xcconfig' } ||
           project.main_group['Flutter'].new_reference('Flutter/Watch.xcconfig')
assets = group['Assets.xcassets'] || group.new_reference('Assets.xcassets')
target.add_resources([assets]) unless target.resources_build_phase.files_references.include?(assets)
# Debug signs automatically; Release/Profile sign for the App Store with
# manual profiles like Runner (an automatically signed watch app inside a
# manually signed Runner fails "Embedded binary is not signed with the same
# certificate"). Profiles: "Tibyan Watch AppStore", "Tibyan Watch Widgets AppStore".
PROFILES = { NAME => 'Tibyan Watch AppStore', WIDGET_NAME => 'Tibyan Watch Widgets AppStore' }.freeze
[target, widget_target].each do |t|
  t.build_configurations.each do |config|
    s = config.build_settings
    s['DEVELOPMENT_TEAM'] = TEAM
    s['CODE_SIGN_ENTITLEMENTS'] = '../apple/TibyanWatch/TibyanWatch.entitlements'
    if config.name == 'Debug'
      s['CODE_SIGN_STYLE'] = 'Automatic'
      s.delete('CODE_SIGN_IDENTITY')
      s.delete('PROVISIONING_PROFILE_SPECIFIER')
    else
      s['CODE_SIGN_STYLE'] = 'Manual'
      s['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
      s['PROVISIONING_PROFILE_SPECIFIER'] = PROFILES[t.name]
    end
    # The project sets SUPPORTED_PLATFORMS = iphoneos for Release/Profile.
    s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
    s.delete('MARKETING_VERSION')
    s.delete('CURRENT_PROJECT_VERSION')
    config.base_configuration_reference = xcconfig
  end
end
target.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.save
puts project.targets.map(&:name).join(', ')

# Flutter "flutter create" yaratgan ios/Runner.xcodeproj ichiga
# WGExtension (Packet Tunnel) target'ini qo'shadi. Repozitoriy ildizidan ishga tushiring.
require 'xcodeproj'
require 'fileutils'

root = Dir.pwd
ios  = File.join(root, 'ios')
tpl  = File.join(root, 'ios_template')

proj = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
app  = proj.targets.find { |t| t.name == 'Runner' } or abort('Runner target topilmadi')
abort('WGExtension allaqachon bor') if proj.targets.any? { |t| t.name == 'WGExtension' }

app_bundle_id = app.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.knowme.knowmeVpn'
app_bundle_id = app_bundle_id.to_s
ext_bundle_id = "#{app_bundle_id}.WGExtension"
puts "App bundle id: #{app_bundle_id}"
puts "Extension bundle id: #{ext_bundle_id}"

# --- fayllarni nusxalash ---
FileUtils.mkdir_p(File.join(ios, 'WGExtension'))
Dir[File.join(tpl, 'WGExtension', '*')].each { |f| FileUtils.cp(f, File.join(ios, 'WGExtension')) }
FileUtils.cp(File.join(tpl, 'Runner.entitlements'), File.join(ios, 'Runner', 'Runner.entitlements'))

# --- extension target ---
ext = proj.new_target(:app_extension, 'WGExtension', :ios, '15.0')
group = proj.main_group.new_group('WGExtension', 'WGExtension')
swift_ref = group.new_file('PacketTunnelProvider.swift')
group.new_file('Info.plist')
group.new_file('WGExtension.entitlements')
ext.add_file_references([swift_ref])

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']     = ext_bundle_id
  s['PRODUCT_NAME']                  = '$(TARGET_NAME)'
  s['INFOPLIST_FILE']                = 'WGExtension/Info.plist'
  s['GENERATE_INFOPLIST_FILE']       = 'NO'
  s['CODE_SIGN_ENTITLEMENTS']        = 'WGExtension/WGExtension.entitlements'
  s['SWIFT_VERSION']                 = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET']    = '15.0'
  s['TARGETED_DEVICE_FAMILY']        = '1,2'
  s['SKIP_INSTALL']                  = 'YES'
  s['CLANG_ENABLE_MODULES']          = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS']       = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# --- Runner entitlements ---
runner_group = proj.main_group['Runner'] || proj.main_group.new_group('Runner', 'Runner')
runner_group.new_file('Runner.entitlements')
app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# --- extension'ni ilova ichiga joylash (PlugIns/) ---
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(ext)

# Xcode "Cycle inside Runner" xatosi bo'lmasligi uchun: Thin Binary'dan oldin
thin = app.build_phases.find { |p| p.respond_to?(:name) && p.name.to_s.include?('Thin Binary') }
if thin
  idx = app.build_phases.index(thin)
  app.build_phases.delete(embed)
  app.build_phases.insert(idx, embed)
end

proj.save
puts 'Xcode project saqlandi'

# --- Podfile: WireGuardKit'ni extension'ga ulash ---
podfile = File.join(ios, 'Podfile')
txt = File.read(podfile)
if txt =~ /^\s*#?\s*platform :ios.*$/
  txt.sub!(/^\s*#?\s*platform :ios.*$/, "platform :ios, '15.0'")
else
  txt = "platform :ios, '15.0'\n" + txt
end
txt << <<~POD

  target 'WGExtension' do
    use_frameworks!
    pod 'WireGuardKit', :git => 'https://git.zx2c4.com/wireguard-apple', :tag => '1.0.15-26'
  end
POD
File.write(podfile, txt)
puts 'Podfile yangilandi'

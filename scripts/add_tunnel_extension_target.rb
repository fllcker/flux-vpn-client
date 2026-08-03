#!/usr/bin/env ruby
# Одноразовый скрипт: добавляет таргет FluxTunnelExtension (System Extension,
# NEPacketTunnelProvider) в macos/Runner.xcodeproj через `xcodeproj` gem —
# см. docs/internal/macos/ROADMAP.md. Ручная правка project.pbxproj текстом
# (как делалось раньше для одного файла FluxDeepLink.swift) для целого
# нового таргета с Info.plist/entitlements/build-фазами слишком рискованна.
require 'xcodeproj'

project_path = File.expand_path('../../macos/Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

if project.targets.find { |t| t.name == 'FluxTunnelExtension' }
  puts 'FluxTunnelExtension target already exists, skipping.'
  project.save
  exit 0
end

ext_group = project.main_group.new_group('FluxTunnelExtension', 'FluxTunnelExtension')
swift_files = %w[main.swift PacketTunnelProvider.swift FluxPlatformInterface.swift].map do |name|
  ext_group.new_file(name)
end
info_plist_ref = ext_group.new_file('Info.plist')
entitlements_ref = ext_group.new_file('FluxTunnelExtension.entitlements')

# :app_extension как ближайший встроенный тип — у этой версии xcodeproj gem
# (1.28.1) нет built-in :system_extension в PRODUCT_TYPE_UTI, System
# Extension новее самого гема. Поправляем productType/расширение продукта
# вручную сразу после создания.
ext_target = project.new_target(
  :app_extension,
  'FluxTunnelExtension',
  :osx,
  nil,
  nil,
  :swift
)
ext_target.product_type = 'com.apple.product-type.system-extension'
product_ref = ext_target.product_reference
product_ref.path = 'FluxTunnelExtension.systemextension'
product_ref.name = 'FluxTunnelExtension.systemextension'
product_ref.explicit_file_type = 'wrapper.system-extension'
product_ref.last_known_file_type = nil

swift_files.each { |ref| ext_target.add_file_references([ref]) }

runner_bundle_id = runner_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'rip.freeinternet.flux'
ext_bundle_id = "#{runner_bundle_id}.tunnel"

ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = ext_bundle_id
  config.build_settings['PRODUCT_NAME'] = 'FluxTunnelExtension'
  config.build_settings['INFOPLIST_FILE'] = 'FluxTunnelExtension/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'FluxTunnelExtension/FluxTunnelExtension.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../../../../Frameworks']
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)/Frameworks']
  # НЕ '$(inherited)' — проектный Debug.xcconfig подключает
  # Pods-Runner.debug.xcconfig (общий для всех таргетов), который прописывает
  # `-framework local_notifier` и другие Flutter-плагины Runner'а; наш таргет
  # их не собирает и не находит (`FRAMEWORK_SEARCH_PATHS` тут другой) —
  # явный сброс вместо наследования, единственный нужный флаг (Cocoa/Libbox)
  # и так добавляется через frameworks_build_phase.
  # Libbox статически линкует часть net-кода Chromium/Go-рантайма, которому
  # нужны SystemConfiguration.framework (SCDynamicStoreCopyProxies и т.п.,
  # см. proxy_config_service_mac.o) и libresolv (res_9_nsearch, DNS-резолвер
  # Go-рантайма) — без них линковка падает "symbol(s) not found", проверено
  # реальной сборкой.
  config.build_settings['OTHER_LDFLAGS'] = ['-lresolv']
  # NEPacketTunnelProvider system extension требует macOS 10.15+ для самого
  # API, но libbox/gomobile-биндинги обычно тянут более новый минимум —
  # 13.0 тут консервативная отправная точка, поправить при первой сборке,
  # если Xcode потребует другое.
end

# Линковка Libbox.xcframework — сам файл кладётся build_libbox_macos.sh в
# macos/Frameworks/Libbox.xcframework (см. Frameworks/SOURCE.md), в git не
# хранится.
frameworks_group = project.main_group.new_group('Frameworks', 'Frameworks') unless project.main_group.find_subpath('Frameworks', false)
frameworks_group ||= project.main_group.find_subpath('Frameworks', false)
libbox_ref = frameworks_group.new_file('Frameworks/Libbox.xcframework')
ext_target.frameworks_build_phase.add_file_reference(libbox_ref)
ext_target.add_system_framework('SystemConfiguration')

# НЕ добавляем runner_target.add_dependency(ext_target) и Copy Files фазу
# сюда: FluxTunnelExtension не подпишется без платного Developer-аккаунта
# (нет com.apple.developer.networking.networkextension), и жёсткая
# зависимость уронила бы обычную сборку Runner (`flutter build macos`),
# которая нужна прямо сейчас для Proxy-режима без аккаунта. FluxTunnelExtension
# остаётся отдельным, независимо собираемым таргетом — когда у друга
# появится аккаунт, он либо перетащит таргет в "Embed System Extensions" в
# Xcode UI (Runner → General → Frameworks, Libraries, and Embedded Content),
# либо доработает этот же скрипт, раскомментировав блок ниже.
#
# copy_phase = runner_target.new_copy_files_build_phase('Embed System Extensions')
# copy_phase.dst_subfolder_spec = '0' # absolute path (via dst_path below)
# copy_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Library/SystemExtensions'
# copy_phase.add_file_reference(ext_target.product_reference, true)
# copy_phase.files.last.settings = { 'ATTRIBUTES' => ['RemoveHeaderOnCopy'] }
# runner_target.add_dependency(ext_target)

project.save
puts 'Added FluxTunnelExtension target.'

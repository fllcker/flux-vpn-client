//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import desktop_webview_window
import file_picker
import local_notifier
import package_info_plus
import screen_retriever_macos
import tray_manager
import video_player_avfoundation
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  DesktopWebviewWindowPlugin.register(with: registry.registrar(forPlugin: "DesktopWebviewWindowPlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  LocalNotifierPlugin.register(with: registry.registrar(forPlugin: "LocalNotifierPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  TrayManagerPlugin.register(with: registry.registrar(forPlugin: "TrayManagerPlugin"))
  VideoPlayerPlugin.register(with: registry.registrar(forPlugin: "VideoPlayerPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}

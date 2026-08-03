import Libbox
import NetworkExtension
import os.log

/// NEPacketTunnelProvider для macOS System Extension — правильный
/// долгосрочный дизайн TUN на macOS (см. docs/internal/macos/ROADMAP.md,
/// "Открытые вопросы"), в отличие от стопгэпа через `osascript` +
/// `sing-box`-подпроцесс (`lib/engines/xray/macos_elevation.dart`): здесь
/// поднятием `utun` и системными маршрутами занимается сам
/// `NEPacketTunnelProvider` (через `setTunnelNetworkSettings`), а не голый
/// `auto_route` sing-box'а поверх самостоятельно созданного `utun` — поэтому
/// не конфликтует по приоритету с другими системными VPN (см. инцидент с
/// v2RayTun в ROADMAP.md) и не требует root/пароля на каждое
/// подключение/отключение.
///
/// sing-box встраивается не подпроцессом, а как библиотека — `libbox`
/// (`Libbox.xcframework`, собран `gomobile bind` из
/// `github.com/sagernet/sing-box/experimental/libbox`, см.
/// `scripts/build_libbox_macos.sh`), тот же пакет, которым пользуется
/// официальный `SagerNet/sing-box-for-apple`. Конфиг — тот же JSON, что
/// строит `buildSingBoxTunBridgeConfig` (singbox_config_mapper.dart) для
/// Windows/старого macOS-стопгэпа, libbox сам разбирает `tun`-инбаунд и
/// зовёт [FluxPlatformInterface.openTun] с уже готовыми
/// адресами/маршрутами/DNS вместо того, чтобы создавать `utun` самому.
///
/// Компилируется и линкуется реально (`xcodebuild` с
/// `CODE_SIGNING_ALLOWED=NO`, см. ROADMAP.md) против `Libbox.xcframework` —
/// не проверен только рантайм (нужен подписанный, активированный System
/// Extension, платный Developer-аккаунт). `LibboxSetup`/`LibboxNewCommandServer`
/// — свободные C-функции, не методы, throws-бриджинг Swift к ним не
/// применяет (в отличие от `server.start()`/`server.startOrReloadService()`
/// — это уже методы, там throws работает) — см. FluxPlatformInterface.swift
/// про переименованные протоколы (`...Protocol`-суффикс).
class PacketTunnelProvider: NEPacketTunnelProvider {
  private var commandServer: LibboxCommandServer?
  private var platformInterface: FluxPlatformInterface?
  private var xrayProcess: Process?
  private var xrayConfigFile: URL?

  private static var setupDone = false

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    // sing-box/libbox тут — чистый packet-capture мост перед xray в
    // Proxy-режиме, тот же архитектурный приём, что и у старого
    // osascript-стопгэпа (см. singbox_config_mapper.dart) — libbox сам по
    // себе не говорит на VLESS/Hysteria2, только socks-outbound к локальному
    // xray. В отличие от App Extension, System Extension — самостоятельный
    // процесс вне контейнера приложения, ему можно спавнить дочерние
    // процессы без дополнительных привилегий (xray тут не поднимает TUN
    // сам, ему только нужен обычный исходящий сокет к серверу — то, что и
    // так разрешено обычным com.apple.security.network.client).
    guard
      let configContent = options?["configContent"] as? String,
      let xrayExecutablePath = options?["xrayExecutablePath"] as? String,
      let xrayConfigContent = options?["xrayConfigContent"] as? String
    else {
      completionHandler(FluxTunnelError.missingConfig)
      return
    }

    do {
      try startXray(executablePath: xrayExecutablePath, configContent: xrayConfigContent)
      if !Self.setupDone {
        // Один раз на процесс жизни расширения — LibboxSetup второй раз
        // подряд (например при повторном startTunnel без выгрузки
        // расширения) не нужен и, судя по назначению полей (базовые пути,
        // командный сервер), не идемпотентен.
        //
        // LibboxSetup — свободная C-функция (`FOUNDATION_EXPORT BOOL
        // LibboxSetup(...)`), а не метод объекта/протокола — Swift НЕ
        // применяет к таким автоматический throws-бриджинг (в отличие от
        // ObjC-методов вида `(BOOL)foo:...error:`), проверено реальной
        // компиляцией: `try LibboxSetup(setupOptions)` не собирается,
        // ожидает второй параметр `NSErrorPointer` явно.
        let baseDir = FluxTunnelPaths.ensureLibboxDirectory()
        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = baseDir
        setupOptions.workingPath = baseDir
        setupOptions.tempPath = NSTemporaryDirectory()
        setupOptions.logMaxLines = 20000
        var setupError: NSError?
        let ok = LibboxSetup(setupOptions, &setupError)
        if !ok {
          throw setupError ?? FluxTunnelError.missingConfig
        }
        Self.setupDone = true
      }

      let platformInterface = FluxPlatformInterface(provider: self)
      self.platformInterface = platformInterface

      var serverError: NSError?
      guard
        let server = LibboxNewCommandServer(
          FluxCommandServerHandler(),
          platformInterface,
          &serverError
        )
      else {
        throw serverError ?? FluxTunnelError.missingConfig
      }
      commandServer = server

      try server.start()
      try server.startOrReloadService(configContent, options: nil as LibboxOverrideOptions?)

      // setTunnelNetworkSettings уже вызван внутри
      // FluxPlatformInterface.openTun(_:ret0_:) — к моменту, когда
      // startOrReloadService успешно вернулся, libbox уже создал
      // tun-инбаунд и, значит, уже дозвался до openTun.
      completionHandler(nil)
    } catch {
      completionHandler(error)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    try? commandServer?.closeService()
    commandServer?.close()
    commandServer = nil
    platformInterface = nil
    xrayProcess?.terminate()
    xrayProcess = nil
    if let xrayConfigFile {
      try? FileManager.default.removeItem(at: xrayConfigFile)
    }
    xrayConfigFile = nil
    completionHandler()
  }

  /// Пишет конфиг xray во временный файл и запускает его как обычный
  /// дочерний процесс расширения (`Process`, не `osascript`/sudo — не
  /// нужен root, см. комментарий у [startTunnel]). Тот же конфиг, что
  /// строит `buildXrayConfig` (`xray_config_mapper.dart`), тот же, каким
  /// пользуется `XrayEngineMacOS` в Proxy-режиме — сюда просто передаётся
  /// уже готовый JSON, а не строится заново.
  private func startXray(executablePath: String, configContent: String) throws {
    let configFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("flux_xray_tunnel_\(UUID().uuidString).json")
    try configContent.write(to: configFile, atomically: true, encoding: .utf8)
    xrayConfigFile = configFile

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = ["run", "-c", configFile.path]
    try process.run()
    xrayProcess = process
  }
}

enum FluxTunnelPaths {
  /// `~/Library/Application Support/flux` per-user каталог из
  /// `lib/app/app_paths.dart` расширению недоступен напрямую (другой
  /// процесс/sandbox-контейнер) — у System Extension свой собственный
  /// каталог группы. `NSHomeDirectory()` внутри System Extension указывает
  /// на её собственный контейнер, что и нужно libbox для base/working path.
  static func ensureLibboxDirectory() -> String {
    let dir = NSHomeDirectory() + "/Library/Application Support/FluxTunnelExtension"
    try? FileManager.default.createDirectory(
      atPath: dir,
      withIntermediateDirectories: true
    )
    return dir
  }
}

import Cocoa
import FlutterMacOS
import NetworkExtension
import SystemExtensions

/// Bundle ID `FluxTunnelExtension`-таргета (`PRODUCT_BUNDLE_IDENTIFIER` в
/// `.build-tools/add_tunnel_extension_target.rb`) — должен совпадать с тем,
/// что реально соберёт друг; если поменяет bundle id приложения, поправить
/// и здесь.
private let tunnelBundleId = "rip.freeinternet.flux.tunnel"

/// Мост `flux/vpn`/`flux/vpn/status` — те же имена каналов, что на Android
/// (`MainActivity.kt`, `xray_engine_android.dart`), см.
/// `docs/internal/macos/ROADMAP.md`. В отличие от старого стопгэпа
/// (`osascript`-элевация, `lib/engines/xray/macos_elevation.dart`), здесь
/// нет прямого управления процессом sing-box — всё через официальный
/// `NETunnelProviderManager`/`OSSystemExtensionRequest`, tunnel сам решает,
/// как поднимать TUN (см. `FluxTunnelExtension/PacketTunnelProvider.swift`).
final class NetworkExtensionBridge: NSObject {
  static let shared = NetworkExtensionBridge()

  private var manager: NETunnelProviderManager?
  private var statusSink: FlutterEventSink?
  private var statusObserver: NSObjectProtocol?
  private var pendingActivationResult: FlutterResult?

  func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "flux/vpn", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }

    let eventChannel = FlutterEventChannel(name: "flux/vpn/status", binaryMessenger: messenger)
    eventChannel.setStreamHandler(NetworkExtensionStatusStreamHandler(bridge: self))
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preparePermission":
      preparePermission(result: result)
    case "start":
      guard
        let args = call.arguments as? [String: Any],
        let configContent = args["configContent"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "missing configContent", details: nil))
        return
      }
      startTunnel(configContent: configContent, result: result)
    case "stop":
      stopTunnel(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Аналог Android `preparePermission` (там — системный диалог VpnService),
  /// здесь — активация System Extension (`OSSystemExtensionRequest`, один
  /// раз показывает пользователю системный запрос в Настройках) плюс
  /// загрузка/создание `NETunnelProviderManager`-конфигурации. НЕ
  /// проверялось в рантайме — на этой машине активация в принципе не может
  /// пройти без платного Developer-аккаунта (см. ROADMAP.md).
  private func preparePermission(result: @escaping FlutterResult) {
    pendingActivationResult = result
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: tunnelBundleId,
      queue: .main
    )
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  private func ensureManager(completion: @escaping (NETunnelProviderManager?, Error?) -> Void) {
    if let manager {
      completion(manager, nil)
      return
    }
    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
      guard let self else { return }
      if let error {
        completion(nil, error)
        return
      }
      if let existing = managers?.first {
        self.manager = existing
        self.observeStatus(existing)
        completion(existing, nil)
        return
      }
      let newManager = NETunnelProviderManager()
      newManager.localizedDescription = "Flux"
      let proto = NETunnelProviderProtocol()
      proto.providerBundleIdentifier = tunnelBundleId
      // serverAddress обязателен (не может быть пустым), но реально не
      // используется — весь адрес сервера уже в configContent, который
      // startTunnel передаёт через options.
      proto.serverAddress = "Flux"
      newManager.protocolConfiguration = proto
      newManager.isEnabled = true
      newManager.saveToPreferences { error in
        if let error {
          completion(nil, error)
          return
        }
        // loadFromPreferences ещё раз — saveToPreferences не всегда сразу
        // даёт валидный session/connection на только что созданном
        // manager'е (стандартная рекомендация Apple-доки NETunnelProviderManager).
        newManager.loadFromPreferences { error in
          if let error {
            completion(nil, error)
            return
          }
          self.manager = newManager
          self.observeStatus(newManager)
          completion(newManager, nil)
        }
      }
    }
  }

  private func startTunnel(configContent: String, result: @escaping FlutterResult) {
    ensureManager { manager, error in
      guard let manager else {
        result(FlutterError(code: "no_manager", message: error?.localizedDescription, details: nil))
        return
      }
      do {
        try manager.connection.startVPNTunnel(options: [
          "configContent": configContent as NSObject
        ])
        result(nil)
      } catch {
        result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    manager?.connection.stopVPNTunnel()
    result(nil)
  }

  private func observeStatus(_ manager: NETunnelProviderManager) {
    if let statusObserver {
      NotificationCenter.default.removeObserver(statusObserver)
    }
    statusObserver = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: manager.connection,
      queue: .main
    ) { [weak self] _ in
      self?.emitStatus(manager.connection.status)
    }
  }

  /// Тот же набор событий, что и `VpnStatusBridge.kt`/`flux/vpn/status` на
  /// Android (`started`/`stopped`/`error`) — `xray_engine_android.dart`
  /// слушает именно эти строки, см. `_listenToNativeStatus`.
  private func emitStatus(_ status: NEVPNStatus) {
    let event: String
    switch status {
    case .connected:
      event = "started"
    case .disconnected, .invalid:
      event = "stopped"
    case .connecting, .disconnecting, .reasserting:
      return
    @unknown default:
      return
    }
    statusSink?(["event": event])
  }

  fileprivate func setStatusSink(_ sink: FlutterEventSink?) {
    statusSink = sink
  }
}

extension NetworkExtensionBridge: OSSystemExtensionRequestDelegate {
  func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    pendingActivationResult?(result == .completed)
    pendingActivationResult = nil
  }

  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
    pendingActivationResult?(FlutterError(code: "activation_failed", message: error.localizedDescription, details: nil))
    pendingActivationResult = nil
  }

  func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    // Пользователь должен вручную разрешить расширение в Системных
    // настройках (Privacy & Security) — didFinishWithResult придёт позже,
    // после его действия, а не сразу.
  }

  func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension ext: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    .replace
  }
}

private class NetworkExtensionStatusStreamHandler: NSObject, FlutterStreamHandler {
  private weak var bridge: NetworkExtensionBridge?

  init(bridge: NetworkExtensionBridge) {
    self.bridge = bridge
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    bridge?.setStatusSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    bridge?.setStatusSink(nil)
    return nil
  }
}

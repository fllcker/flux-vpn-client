import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerDeepLinkChannels(messenger: flutterViewController.engine.binaryMessenger)
    NetworkExtensionBridge.shared.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // Те же имена каналов, что у Android (`MainActivity.kt`) — см.
  // `lib/app/deep_link.dart` и `FluxDeepLink.swift`.
  private func registerDeepLinkChannels(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "flux/deeplink", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getInitialLink":
          result(FluxDeepLink.pendingLink)
          FluxDeepLink.pendingLink = nil
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    let eventChannel = FlutterEventChannel(name: "flux/deeplink/stream", binaryMessenger: messenger)
    eventChannel.setStreamHandler(FluxDeepLinkStreamHandler())
  }
}

private class FluxDeepLinkStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    FluxDeepLink.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    FluxDeepLink.eventSink = nil
    return nil
  }
}

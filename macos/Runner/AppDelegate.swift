import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Флаг close-to-tray (см. main.dart, windowManager.setPreventClose) уже
  // делает closing прозрачным для window_manager — оставляем true здесь же,
  // как в шаблоне flutter create, unrelated to that flag.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Регистрировать обработчик kAEGetURL нужно до того, как ОС успеет
  // доставить событие холодного запуска по flux://... — по документации
  // Apple это гарантированно так только в applicationWillFinishLaunching,
  // не в applicationDidFinishLaunching (где уже мог бы запуститься и
  // потеряться race с диспетчеризацией события).
  override func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
    guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
    FluxDeepLink.handle(urlString)
  }
}

import FlutterMacOS

/// Мост `flux://...` для Dart-стороны (`lib/app/deep_link.dart`) — те же
/// имена каналов, что и у Android (`MainActivity.kt`), потому что оба
/// платформы доставляют диплинк событием, а не argv (см. комментарий в
/// `deep_link.dart`).
///
/// Apple Event `kAEGetURL` может прийти ещё до того, как Flutter engine
/// поднят и `MainFlutterWindow` зарегистрировал каналы (обрабатывается в
/// `AppDelegate.applicationWillFinishLaunching`, которая гарантированно
/// раньше) — поэтому холодный старт всегда буферизуется в [pendingLink] и
/// забирается один раз через `getInitialLink`, а не сразу шлётся в
/// [eventSink].
enum FluxDeepLink {
  static var pendingLink: String?
  static var eventSink: FlutterEventSink?

  static func handle(_ link: String) {
    if let sink = eventSink {
      sink(link)
    } else {
      pendingLink = link
    }
  }
}

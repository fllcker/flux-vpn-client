import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:win32/win32.dart';

import '../../app/app_paths.dart';

const whatsappWebUrl = 'https://web.whatsapp.com/';
const webviewRuntimeUrl =
    'https://developer.microsoft.com/microsoft-edge/webview2/';

enum WhatsappOpenResult {
  opened,
  unsupported,
  runtimeMissing,
  failed,
  cancelled,
}

/// One browser window and one persistent profile, separate from the user's Edge.
class WhatsappWindow {
  static final instance = WhatsappWindow();

  final bool Function() _supported;
  final Future<bool> Function() _available;
  final Future<Webview> Function(CreateConfiguration) _create;
  final Future<Directory> Function() _profile;
  final void Function(int) _focus;
  Webview? _window;
  Future<WhatsappOpenResult>? _opening;

  WhatsappWindow({
    bool Function()? supported,
    Future<bool> Function()? available,
    Future<Webview> Function(CreateConfiguration)? create,
    Future<Directory> Function()? profile,
    void Function(int)? focus,
  }) : _supported = supported ?? (() => Platform.isWindows),
       _available = available ?? WebviewWindow.isWebviewAvailable,
       _create =
           create ?? ((config) => WebviewWindow.create(configuration: config)),
       _profile =
           profile ??
           (() async => Directory('${fluxDataDirectoryPath()}/whatsapp-web')),
       _focus = focus ?? _focusNativeWindow;

  bool get opening => _opening != null;

  Future<WhatsappOpenResult> open() =>
      _opening ??= _open().whenComplete(() => _opening = null);

  Future<WhatsappOpenResult> _open() async {
    if (!_supported()) return WhatsappOpenResult.unsupported;
    Webview? created;
    try {
      final existing = _window;
      if (existing != null && existing.nativeWindowHandle != 0) {
        _focus(existing.nativeWindowHandle);
        return WhatsappOpenResult.opened;
      }
      _window = null;
      if (!await _available()) return WhatsappOpenResult.runtimeMissing;
      final directory = await _profile();
      await directory.create(recursive: true);
      created = await _create(
        CreateConfiguration(
          title: 'WhatsApp — Flux',
          windowWidth: 1080,
          windowHeight: 720,
          windows: WindowsWebviewOptions(
            userDataFolder: directory.absolute.path,
          ),
        ),
      );
      if (created.nativeWindowHandle == 0) return WhatsappOpenResult.cancelled;
      _window = created;
      unawaited(_watchClose(created));
      // Native navigation/reload controls stay available for connection errors.
      // No scripts, chat bridges or cookie access are installed by Flux.
      await created.launch(whatsappWebUrl);
      return WhatsappOpenResult.opened;
    } catch (_) {
      if (created != null) {
        try {
          await created.close();
        } catch (_) {}
        if (identical(_window, created)) _window = null;
      }
      return WhatsappOpenResult.failed;
    }
  }

  Future<void> _watchClose(Webview window) async {
    try {
      await window.onClose;
    } catch (_) {
    } finally {
      if (identical(_window, window)) _window = null;
    }
  }

  static void _focusNativeWindow(int address) {
    final handle = HWND(Pointer.fromAddress(address));
    if (IsIconic(handle)) ShowWindow(handle, SW_RESTORE);
    SetForegroundWindow(handle);
  }
}

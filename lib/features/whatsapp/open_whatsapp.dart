import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../l10n/strings.dart';
import '../../widgets/port_ui/port_ui.dart';
import 'whatsapp_window.dart';

Future<void> openWhatsapp(
  BuildContext context, {
  WhatsappWindow? window,
}) async {
  final service = window ?? WhatsappWindow.instance;
  if (service.opening) return;
  PortToaster.of(context).show(PortToast(title: Text(S.whatsappOpening)));
  final result = await service.open();
  if (!context.mounted ||
      result == WhatsappOpenResult.opened ||
      result == WhatsappOpenResult.cancelled) {
    return;
  }
  await showPortDialog<void>(
    context: context,
    builder: (dialogContext) => PortDialog(
      title: Text(
        result == WhatsappOpenResult.runtimeMissing
            ? S.whatsappRuntimeTitle
            : 'WhatsApp Web',
      ),
      description: Text(switch (result) {
        WhatsappOpenResult.runtimeMissing => S.whatsappRuntimeDescription,
        WhatsappOpenResult.unsupported => S.whatsappWindowsOnly,
        _ => S.whatsappOpenError,
      }),
      actions: [
        PortButton.secondary(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(S.whatsappClose),
        ),
        if (result == WhatsappOpenResult.runtimeMissing)
          PortButton(
            onPressed: () async {
              try {
                await Process.start('explorer.exe', [webviewRuntimeUrl]);
              } catch (_) {
                if (context.mounted) {
                  PortToaster.of(context).show(
                    PortToast.destructive(title: Text(S.whatsappBrowserError)),
                  );
                }
              }
            },
            child: Text(S.whatsappRuntimeDownload),
          ),
      ],
    ),
  );
}

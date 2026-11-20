import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flux/features/assistant/assistant_panel.dart';
import 'package:flux/l10n/strings.dart';
import 'package:flux/widgets/port_ui/port_ui.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'server recommendation reads current subscriptions on each click',
    (tester) async {
      var servers = <String>[];
      await tester.pumpWidget(
        PortApp(
          home: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 380,
              child: AssistantPanel(onClose: () {}, serverNames: () => servers),
            ),
          ),
        ),
      );
      expect(find.byType(PortButton), findsNWidgets(4));
      await tester.tap(find.text(S.assistantPickServer));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(S.assistantNoServers), findsOneWidget);

      servers = ['Germany (My subscription)'];
      // The button label is also present in the chat after the first request.
      await tester.tap(find.widgetWithText(PortButton, S.assistantPickServer));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.text(S.assistantServerRecommendation(servers.single)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preset produces an answer and custom text gets fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      PortApp(
        home: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(width: 380, child: AssistantPanel(onClose: () {})),
        ),
      ),
    );
    expect(find.text(S.assistantGreeting), findsOneWidget);

    final prompt = S.assistantPrompts.first;
    await tester.tap(find.text(prompt.question));
    await tester.pump();
    expect(find.text(S.assistantTyping), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      prompt.answers.where((answer) => find.text(answer).evaluate().isNotEmpty),
      hasLength(1),
    );

    await tester.enterText(find.byType(TextField), 'My own question');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('My own question'), findsOneWidget);
    expect(find.text(S.assistantFallback), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits narrow screen and closes', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closed = false;
    await tester.pumpWidget(
      PortApp(home: AssistantPanel(onClose: () => closed = true)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel(S.assistantClose));
    expect(closed, isTrue);
  });
}

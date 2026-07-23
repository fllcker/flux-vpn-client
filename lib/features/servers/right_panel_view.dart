import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Что показано справа от списка серверов — по умолчанию карточка
/// подключения к выбранному серверу, либо (по клику на заголовок подписки
/// слева) информация о конкретной подписке.
sealed class RightPanelView {
  const RightPanelView();
}

class ConnectView extends RightPanelView {
  const ConnectView();
}

class SubscriptionInfoView extends RightPanelView {
  final String subscriptionId;
  const SubscriptionInfoView(this.subscriptionId);
}

final rightPanelViewProvider =
    NotifierProvider<RightPanelViewController, RightPanelView>(
      RightPanelViewController.new,
    );

class RightPanelViewController extends Notifier<RightPanelView> {
  @override
  RightPanelView build() => const ConnectView();

  void showConnect() => state = const ConnectView();

  void showSubscription(String subscriptionId) =>
      state = SubscriptionInfoView(subscriptionId);
}

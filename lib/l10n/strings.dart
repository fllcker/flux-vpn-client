import 'app_locale.dart';
import '../core_abstraction/app_settings.dart';

bool get _en => AppLocale.effective == AppLanguage.en;

/// Строки интерфейса — RU/EN пара на каждую запись, сгруппированные по
/// экрану/файлу комментариями. Не включает: имена серверов/подписок (это
/// данные, не литералы), протокольные/технические токены, которые не
/// переводятся (TCP, ICMP, sing-box, xray-core, Magic JSON, DNS, HTTP,
/// UAC, Simple Gradient/Color Bends/Galaxy — имена шейдерных фонов) — они
/// остаются обычными строковыми литералами в месте использования, и
/// селектор режима Off/Proxy/TUN (`off_proxy_tun_selector.dart`), у
/// которого лейблы уже на английском независимо от языка интерфейса.
abstract final class S {
  // connect_panel.dart
  static String get disconnected => _en ? 'Disconnected' : 'Отключено';
  static String get connectingStatus => _en ? 'Connecting...' : 'Подключение...';
  static String get disconnectingStatus => _en ? 'Disconnecting...' : 'Отключение...';
  static String connectionError(String message) =>
      _en ? 'Error: $message' : 'Ошибка: $message';
  static String get adminRightsNeededTitle =>
      _en ? 'Administrator rights needed' : 'Нужны права администратора';
  static String get adminRightsNeededDescription => _en
      ? 'TUN mode requires administrator rights. Restart the app with elevated rights?'
      : 'Режим TUN требует прав администратора. Перезапустить приложение с повышенными правами?';
  static String get cancel => _en ? 'Cancel' : 'Отмена';
  static String get restart => _en ? 'Restart' : 'Перезапустить';
  static String get selectServerHint =>
      _en ? 'Select a server on the left to connect.' : 'Выберите сервер слева, чтобы подключиться.';

  // app/tray.dart
  static String get trayOpen => _en ? 'Open' : 'Открыть';
  static String get trayDisconnect => _en ? 'Disconnect' : 'Отключить';
  static String get trayConnect => _en ? 'Connect' : 'Подключить';
  static String get trayExit => _en ? 'Exit' : 'Выход';

  // server_list_panel.dart
  static String routingTitleFor(String serverName) =>
      _en ? 'Routing — $serverName' : 'Роутинг — $serverName';
  static String get cannotPingInTun =>
      _en ? "Can't ping in TUN mode" : 'Нельзя пинговать в TUN-режиме';
  static String get pingBlocksTunDescription => _en
      ? 'Measuring latency conflicts with an active TUN connection — disconnect or switch to Proxy to ping.'
      : 'Измерение задержки мешает активному TUN-соединению — отключитесь или переключитесь на Proxy, чтобы пинговать.';
  static String get servers => _en ? 'Servers' : 'Серверы';
  static String get noServersYet =>
      _en ? 'No servers yet — add a subscription or a link.' : 'Пока нет серверов — добавьте подписку или ссылку.';

  // server_row.dart
  static String get routing => _en ? 'Routing' : 'Роутинг';
  static String get hide => _en ? 'Hide' : 'Скрыть';

  // subscription_info_panel.dart
  static String get subscriptionDeleted => _en ? 'Subscription deleted' : 'Подписка удалена';
  static String get subscriptionNoLongerServing =>
      _en ? 'The subscription link no longer returns a subscription' : 'Ссылка подписки больше не отдаёт подписку';
  static String get unexpectedMagicJsonResponse =>
      _en ? 'Unexpected Magic JSON response' : 'Неожиданный ответ Magic JSON';
  static String get updated => _en ? 'Updated' : 'Обновлено';
  static String get expiresLabel => _en ? 'Expires' : 'Истекает';
  static String get remaining => _en ? 'Remaining' : 'Осталось';
  static String get traffic => _en ? 'Traffic' : 'Трафик';
  static String get refreshOnStartup =>
      _en ? 'Refresh on app startup' : 'Обновлять при запуске приложения';
  static String get resetSorting => _en ? 'Reset sorting' : 'Сбросить сортировку';
  static String get hiddenServers => _en ? 'Hidden servers' : 'Скрытые серверы';
  static String get restore => _en ? 'Restore' : 'Вернуть';
  static String get deleteSubscription => _en ? 'Delete subscription' : 'Удалить подписку';
  static String get rulesDifferBetweenServers =>
      _en ? 'Rules differ between servers' : 'Правила различаются по серверам';
  static String get setSameRulesForAll =>
      _en ? 'Set the same rules for all' : 'Задать одинаковые правила для всех';
  static String get noRulesAllViaProxy =>
      _en ? 'No rules — all traffic goes through the proxy' : 'Правил нет — весь трафик через прокси';
  static String get expired => _en ? 'expired' : 'истекла';
  static String get lessThanADay => _en ? 'less than a day' : 'меньше дня';

  // import_subscription_sheet.dart
  static String get addServer => _en ? 'Add server' : 'Добавить сервер';
  static String get subscriptionOrVlessLinkDescription =>
      _en ? 'A subscription link or a vless:// link' : 'Ссылка на подписку или vless:// ссылка';
  static String get adding => _en ? 'Adding...' : 'Добавление...';
  static String get add => _en ? 'Add' : 'Добавить';
  static String get linkPlaceholder =>
      _en ? 'https://... or vless://...' : 'https://... или vless://...';

  // routing_rules_dialog.dart
  static String get noRulesYet => _en ? 'No rules yet' : 'Правил пока нет';
  static String get domain => _en ? 'Domain' : 'Домен';
  static String get throughProxy => _en ? 'Through proxy' : 'Через прокси';
  static String get direct => _en ? 'Direct' : 'Напрямую';
  static String get block => _en ? 'Block' : 'Блокировать';
  static String get save => _en ? 'Save' : 'Сохранить';

  // settings_page.dart — навигация секций
  static String get sectionPersonalization => _en ? 'Personalization' : 'Персонализация';
  static String get sectionPing => _en ? 'Ping' : 'Пинг';
  static String get sectionSubscription => _en ? 'Subscription' : 'Подписка';
  static String get sectionSystem => _en ? 'System' : 'Система';
  static String get sectionLogs => _en ? 'Logs' : 'Логи';
  static String get sectionAbout => _en ? 'About' : 'О программе';
  static String get settingsTitle => _en ? 'Settings' : 'Настройки';

  // settings_page.dart — персонализация
  static String get themeLabel => _en ? 'Theme' : 'Тема';
  static String get themeSystem => _en ? 'System' : 'Системная';
  static String get themeLight => _en ? 'Light' : 'Светлая';
  static String get themeDark => _en ? 'Dark' : 'Тёмная';
  static String get languageLabel => _en ? 'Language' : 'Язык';
  static String get languageSystem => _en ? 'System' : 'Системный';
  static String get homeBackgroundLabel => _en ? 'Home background' : 'Фон на главной';
  static String get backgroundNone => _en ? 'None' : 'Нет';
  static String get backgroundGlobe => _en ? 'Globe' : 'Планета';

  // settings_page.dart — пинг
  static String get checkMethodLabel => _en ? 'Check method' : 'Способ проверки';
  static String get checkUrlLabel =>
      _en ? 'Check URL (through proxy)' : 'URL для проверки (через прокси)';
  static String get pingAllOnStartupLabel =>
      _en ? 'Ping all servers on startup' : 'Пинговать все серверы при открытии';

  // settings_page.dart — TUN
  static String get tunCoreLabel => _en ? 'TUN mode core' : 'Ядро TUN-режима';
  static String get tunDnsLabel => _en ? 'DNS server (TUN only)' : 'DNS-сервер (только TUN)';
  static String get proxyDnsNote => _en
      ? "An address, not a name — resolving the resolver itself would be circular. In Proxy mode the server resolves names, so this setting doesn't affect it."
      : 'Адресом, а не именем — резолвить сам резолвер было бы замкнутым кругом. В Proxy-режиме имена резолвит сервер, поэтому настройка на него не влияет.';

  // settings_page.dart — подписка/система
  static String get autoGroupLabel =>
      _en ? 'Automatically split into groups' : 'Автоматическая разбивка по группам';
  static String get autoStartLabel =>
      _en ? 'Start with Windows' : 'Запускать при старте Windows';

  // settings_page.dart — логи
  static String get verbosityLabel => _en ? 'Verbosity' : 'Подробность';
  static String get logErrorsOnly => _en ? 'Errors only' : 'Только ошибки';
  static String get logWarnings => _en ? 'Warnings' : 'Предупреждения';
  static String get logDetailed => _en ? 'Detailed' : 'Подробно';
  static String get logDebug => _en ? 'Debug' : 'Отладка';
  static String get logLevelNote => _en
      ? 'The level applies on the next connection. At "Debug" you can see every connection and routing decision — that\'s what TUN issues are diagnosed with, but the log grows by hundreds of kilobytes per minute.'
      : 'Уровень применяется при следующем подключении. На «Отладке» видно каждое соединение и решения роутинга — этим и разбираются проблемы TUN, но лог растёт на сотни килобайт за минуты.';
  static String get openLogsFolder => _en ? 'Open logs folder' : 'Открыть папку с логами';

  // settings_page.dart — о программе
  static String get built => _en ? 'Built' : 'Собрано';
  static String get notFound => _en ? 'not found' : 'не найден';
  static String get versionsLabel => _en ? 'Versions' : 'Версии';
  static String get couldNotDetermine => _en ? 'could not be determined' : 'не удалось определить';
  static String get unknown => _en ? 'unknown' : 'неизвестно';
  static String buildNumberSuffix(String buildNumber) =>
      _en ? 'build $buildNumber' : 'сборка $buildNumber';

  // clipboard_import_hotkey.dart
  static String get serverAddedFromClipboard =>
      _en ? 'Server added from clipboard' : 'Сервер добавлен из буфера обмена';
  static String get subscriptionUpdated => _en ? 'Subscription updated' : 'Подписка обновлена';
  static String get subscriptionAddedFromClipboard =>
      _en ? 'Subscription added from clipboard' : 'Подписка добавлена из буфера обмена';
  static String get magicJsonFromClipboard =>
      _en ? 'Magic JSON from clipboard' : 'Magic JSON из буфера обмена';
  static String get clipboardImportFailedTitle =>
      _en ? 'Could not add from clipboard' : 'Не удалось добавить из буфера обмена';

  // subscription_import.dart
  static String get expectedLinkError => _en
      ? 'Expected a link: vless://.../hysteria2://... or an http(s):// subscription link'
      : 'Ожидается ссылка: vless://.../hysteria2://... или http(s)://ссылка-на-подписку';
  static String downloadFailedHttp(int statusCode) => _en
      ? 'Failed to download subscription: HTTP $statusCode'
      : 'Не удалось скачать подписку: HTTP $statusCode';
  static String downloadFailedGeneric(Object error) => _en
      ? 'Failed to download subscription: $error'
      : 'Не удалось скачать подписку: $error';
  static String invalidMagicJson(String message) =>
      _en ? 'Invalid Magic JSON: $message' : 'Некорректный Magic JSON: $message';
  static String get noSupportedServersFound => _en
      ? 'No supported servers found in the subscription'
      : 'В подписке не нашлось ни одного поддерживаемого сервера';
  static String get defaultSubscriptionName => _en ? 'Subscription' : 'Подписка';
  static String get subscriptionNoLongerInMj => _en
      ? 'This subscription is no longer part of the Magic JSON returned by this URL'
      : 'Эта подписка больше не входит в Magic JSON, отдаваемый этим URL';
  static String get urlNowReturnsMjNodes => _en
      ? "This subscription's URL now returns Magic JSON with nodes instead of a subscription — add it again via the add-server dialog"
      : 'URL этой подписки теперь отдаёт Magic JSON с узлами, а не подписку — добавьте его заново через диалог добавления сервера';

  // connection_controller.dart
  static String get engineFailedWithError =>
      _en ? 'The core exited with an error' : 'Ядро завершилось с ошибкой';

  // vless_link_parser.dart / hysteria2_link_parser.dart — сообщения из
  // FormatException, всплывающие до UI как LinkImportFailure.reason.
  static String get vlessLinkMustStartWith =>
      _en ? 'The link must start with vless://' : 'Ссылка должна начинаться с vless://';
  static String get linkMissingUuid => _en ? 'The link is missing a UUID' : 'В ссылке отсутствует UUID';
  static String get linkMissingAddressOrPort =>
      _en ? 'The link is missing an address or port' : 'В ссылке отсутствует адрес или порт';
  static String unsupportedTransport(String value) =>
      _en ? 'Unsupported transport: $value' : 'Неподдерживаемый транспорт: $value';
  static String unsupportedSecurity(String value) =>
      _en ? 'Unsupported security: $value' : 'Неподдерживаемый security: $value';
  static String get hysteria2LinkMustStartWith => _en
      ? 'The link must start with hysteria2:// or hy2://'
      : 'Ссылка должна начинаться с hysteria2:// или hy2://';
  static String get linkMissingPassword =>
      _en ? 'The link is missing a password' : 'В ссылке отсутствует пароль';

  // tun_bridge_engine.dart
  static String get tunRequiresAdminRights => _en
      ? 'TUN mode requires administrator rights — the app is running without them'
      : 'TUN-режим требует прав администратора — приложение запущено без них';

  // xray_engine_android.dart
  static String get vpnPermissionDenied => _en
      ? 'VPN permission was not granted'
      : 'Разрешение на VPN не выдано';

  // apply_mj_payload.dart
  static String subscriptionsAdded(int count) =>
      _en ? 'Subscriptions added: $count' : 'Добавлено подписок: $count';
  static String subscriptionsUpdated(int count) =>
      _en ? 'Subscriptions updated: $count' : 'Обновлено подписок: $count';
  static String subscriptionsAddedAndUpdated(int added, int updated) => _en
      ? 'Added: $added, updated: $updated'
      : 'Добавлено: $added, обновлено: $updated';
  static String serversFromMagicJson(int count) =>
      _en ? 'Servers from Magic JSON: $count' : 'Серверов из Magic JSON: $count';
}

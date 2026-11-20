import 'app_locale.dart';
import '../core_abstraction/app_settings.dart';
import '../core_abstraction/connection_session.dart';

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
  static String get minerTitle => _en ? 'Miner' : 'Шахтёр';
  static String get minerMeters => _en ? 'm' : 'м';
  static String get minerInstructions => _en ? 'Arrows / WASD or click a neighbouring block to move and dig. Ladders appear automatically.' : 'Стрелки / WASD или клик по соседнему блоку — идти и копать. Лестницы появляются автоматически.';
  static String get minerUp => _en ? 'Dig up' : 'Копать вверх';
  static String get minerDown => _en ? 'Dig down' : 'Копать вниз';
  static String get minerLeft => _en ? 'Dig left' : 'Копать влево';
  static String get minerRight => _en ? 'Dig right' : 'Копать вправо';
  static String get minerSurface => _en ? 'Lift to surface' : 'Лифт на поверхность';
  static String get minerShop => _en ? 'Upgrades' : 'Улучшения';
  static String get minerSurfaceOnly => _en ? 'Shop and selling are on the surface.' : 'Магазин и продажа — на поверхности.';
  static String minerSell(int value) => _en ? 'Sell ore · $value' : 'Продать руду · $value';
  static String minerSold(int value) => _en ? 'Ore sold for $value coins.' : 'Руда продана за $value монет.';
  static String minerPick(int level, String price) => _en ? 'Pickaxe $level → $price' : 'Кирка $level → $price';
  static String minerBag(int capacity, String price) => _en ? 'Backpack $capacity → $price' : 'Рюкзак $capacity → $price';
  static String get minerBagFull => _en ? 'Backpack full! Take the lift and sell your ore.' : 'Рюкзак полон! Поднимись на лифте и продай руду.';
  static String get minerBottom => _en ? 'Mine bottom reached! Return and open a new shaft.' : 'Ты достиг дна шахты! Возвращайся и открывай новую.';
  static String get minerNewShaft => _en ? 'New shaft' : 'Новая шахта';
  static String get minerNewShaftHint => _en ? 'Generate a fresh mine? Coins, backpack contents, upgrades and depth record are preserved.' : 'Создать новую шахту? Монеты, содержимое рюкзака, улучшения и рекорд глубины сохранятся.';
  static String get minerLoadError => _en ? 'Could not load the save. Original file is unchanged. Start over to replace it.' : 'Не удалось загрузить сохранение. Файл не изменён. Можно начать заново.';
  static String get minerSaveError => _en ? 'Could not save progress. Try exiting again to retry.' : 'Не удалось сохранить прогресс. Попробуй выйти ещё раз для повторной записи.';
  static String get minerStartOver => _en ? 'Start over' : 'Начать заново';
  static String minerOre(int index) => (_en ? ['Air', 'Dirt', 'Stone', 'Coal', 'Copper', 'Gold', 'Crystal'] : ['Воздух', 'Земля', 'Камень', 'Уголь', 'Медь', 'Золото', 'Кристалл'])[index];
  static String bkbRemaining(int seconds) => _en ? 'BKB · $seconds s' : 'БКБ · $seconds с';
  static String get bkbWindowError => _en ? 'Could not resize the window.' : 'Не удалось изменить размер окна.';
  static String get whatsappOpening => _en ? 'Opening WhatsApp Web…' : 'Открываем WhatsApp Web…';
  static String get whatsappWindowsOnly => _en ? 'WhatsApp Web in this version is available on Windows.' : 'WhatsApp Web в этой версии доступен на Windows.';
  static String get whatsappOpenError => _en ? 'Could not open the WhatsApp window. Try again.' : 'Не удалось открыть окно WhatsApp. Попробуй ещё раз.';
  static String get whatsappRuntimeTitle => _en ? 'Microsoft Edge WebView2 required' : 'Нужен Microsoft Edge WebView2';
  static String get whatsappRuntimeDescription => _en ? 'Install the WebView2 Runtime from Microsoft, then open WhatsApp again.' : 'Установи WebView2 Runtime с сайта Microsoft, затем открой WhatsApp ещё раз.';
  static String get whatsappRuntimeDownload => _en ? 'Microsoft website' : 'Сайт Microsoft';
  static String get whatsappBrowserError => _en ? 'Could not open the browser. Visit developer.microsoft.com/microsoft-edge/webview2/' : 'Не удалось открыть браузер. Адрес: developer.microsoft.com/microsoft-edge/webview2/';
  static String get whatsappClose => _en ? 'Close' : 'Закрыть';
  static String get doomTagline => _en ? 'Of course your VPN runs DOOM.' : 'Конечно, твой VPN запускает DOOM.';
  static String get doomCampaign => _en ? 'CAMPAIGN' : 'КАМПАНИЯ';
  static String get doomOwnWad => _en ? 'Choose own WAD' : 'Выбрать свой WAD';
  static String get doomDescription => _en ? 'The Crispy Doom engine with the free Freedoom campaign is included. You can also select your own original DOOM or DOOM II IWAD.' : 'В комплекте движок Crispy Doom и бесплатная кампания Freedoom. Можно выбрать свой IWAD оригинального DOOM или DOOM II.';
  static String get doomPlay => _en ? 'PLAY' : 'ИГРАТЬ';
  static String get doomRunning => _en ? 'GAME IS RUNNING' : 'ИГРА ЗАПУЩЕНА';
  static String get doomStarting => _en ? 'PREPARING…' : 'ПОДГОТОВКА…';
  static String get doomWindowHint => _en ? 'Opens in a separate window. Works offline. Saves stay on this device.' : 'Откроется в отдельном окне. Работает без интернета. Сохранения остаются на этом устройстве.';
  static String get doomRunningHint => _en ? 'Switch to the game window. Quit from its menu to return. You can keep using the VPN.' : 'Переключись в окно игры. Выход — через её меню. VPN можно продолжать пользоваться.';
  static String get doomWindowsOnly => _en ? 'This version of DOOM is available on Windows.' : 'Эта версия DOOM доступна на Windows.';
  static String get doomNotInstalled => _en ? 'Game files are missing from this build.' : 'В этой сборке отсутствуют файлы игры.';
  static String get doomLaunchError => _en ? 'The game could not start or exited with an error. Try again.' : 'Игра не запустилась или завершилась с ошибкой. Попробуй ещё раз.';
  static String get doomInvalidWad => _en ? 'Choose a complete DOOM/DOOM II IWAD, not a PWAD mod or a damaged file.' : 'Выбери полный IWAD DOOM/DOOM II, а не PWAD-мод или повреждённый файл.';
  static String get doomImportError => _en ? 'Could not copy this WAD. Check that the file is accessible.' : 'Не удалось скопировать WAD. Проверь доступность файла.';
  static String get doomControls => _en ? 'Controls' : 'Управление';
  static String get doomMove => _en ? 'Move / turn' : 'Движение / поворот';
  static String get doomFire => _en ? 'Fire' : 'Стрелять';
  static String get doomUse => _en ? 'Open doors / use' : 'Двери / действие';
  static String get doomWeapon => _en ? 'Select weapon' : 'Выбрать оружие';
  static String get doomMenu => _en ? 'Menu / quit' : 'Меню / выход';
  static String get doomSaveLoad => _en ? 'Save / load' : 'Сохранить / загрузить';
  static String get doomControlsHint => _en ? 'Default controls. Alt+Enter toggles fullscreen.' : 'Управление по умолчанию. Alt+Enter — полный экран.';
  static String get boomboxTitle => _en ? 'Boombox' : 'Магнитофон';
  static String get tapeSubtitle => _en ? 'Your MP3s. A little more analogue.' : 'Твои MP3. Чуть больше аналогового тепла.';
  static String get tapeShelf => _en ? 'Cassette collection' : 'Коллекция кассет';
  static String get tapeShelfHint => _en ? 'Import MP3s, then drag a cassette into the deck. Drag it back here to eject. You can also click a cassette.' : 'Импортируй MP3 и перетащи кассету в деку. Чтобы вынуть — перетащи обратно сюда. Можно и просто нажать на кассету.';
  static String get tapeImport => _en ? 'Import MP3' : 'Импорт MP3';
  static String get tapeImporting => _en ? 'Making cassettes…' : 'Записываем кассеты…';
  static String get tapeLoading => _en ? 'Loading cassette…' : 'Загружаем кассету…';
  static String get tapeEmptyShelf => _en ? 'Your first mixtape starts here.' : 'Здесь начнётся твой первый микстейп.';
  static String get tapeEmptyDeck => _en ? 'INSERT CASSETTE' : 'ВСТАВЬ КАССЕТУ';
  static String get tapeReturnHint => _en ? 'Drop the cassette here to return it to the shelf.' : 'Перетащи кассету сюда, чтобы вернуть на полку.';
  static String get tapeInsertHint => _en ? 'Drag to deck or click to play' : 'Перетащи в деку или нажми для воспроизведения';
  static String get tapeEjectHint => _en ? 'Drag back to shelf to eject' : 'Перетащи на полку, чтобы вынуть';
  static String get tapePlay => _en ? 'Play' : 'Воспроизвести';
  static String get tapePause => _en ? 'Pause' : 'Пауза';
  static String get tapeStop => _en ? 'Stop' : 'Стоп';
  static String get tapeRewind => _en ? 'Rewind 10 seconds' : 'Назад на 10 секунд';
  static String get tapeEject => _en ? 'Eject cassette' : 'Вынуть кассету';
  static String get tapeVolume => _en ? 'Volume' : 'Громкость';
  static String get tapeLibraryError => _en ? 'Could not open the cassette collection.' : 'Не удалось открыть коллекцию кассет.';
  static String get tapeImportError => _en ? 'Some files could not be imported. Select readable, non-empty MP3 files.' : 'Не все файлы удалось импортировать. Выбери доступные непустые MP3.';
  static String get tapePlaybackError => _en ? 'Could not play this cassette. Try another MP3 or eject and reinsert it.' : 'Не удалось воспроизвести кассету. Попробуй другой MP3 или вынь и вставь её снова.';
  static String get dagonTitle => _en ? 'Dagon' : 'Дагон';
  static String dagonLevel(int level) => _en ? 'Level $level' : 'Уровень $level';
  static String get dagonCaption => _en ? 'You asked for Dagon in a VPN. Here it is.' : 'Просили Дагон в VPN? Вот Дагон в VPN.';
  static String get roflFeatures => _en ? 'Fun features' : 'Рофлофункции';
  static String get flashlightTitle => _en ? 'Flashlight' : 'Фонарик';
  static String get flashlightSubtitle => _en ? 'Light at the end of the VPN tunnel.' : 'Свет в конце VPN-туннеля.';
  static String get flashlightClose => _en ? 'Back' : 'Назад';
  static String get flashlightBrightness => _en ? 'Brightness' : 'Яркость';
  static String get flashlightLength => _en ? 'Beam length' : 'Длина луча';
  static String get flashlightWidth => _en ? 'Beam width' : 'Ширина луча';
  static String get flashlightHighBeam => _en ? 'High beam' : 'Дальний свет';
  static String get flashlightOrbital => _en ? 'Orbital beam' : 'До орбиты';
  static String get flashlightKm => _en ? 'km' : 'км';
  static String get flashlightOff => _en ? 'OFF' : 'ВЫКЛ';
  static String get flashlightDistanceHint => _en ? 'Imaginary range. Real commitment.' : 'Дальность выдуманная. Намерения серьёзные.';
  static String get flashlightPower => _en ? 'Toggle flashlight' : 'Включить или выключить фонарик';
  static String get flashlightScreen => _en ? 'Screen light' : 'Светить экраном';
  static String get flashlightBackToBeam => _en ? 'Back to beam' : 'Вернуться к лучу';
  static String get flashlightGestureHint => _en ? 'Drag the beam: up for distance, sideways for width.' : 'Тяни луч: вверх — дальше, в стороны — шире.';
  // Scripted assistant
  static String get assistantPickServer => _en ? 'Pick a server for me' : 'Подбери сервер';
  static String get assistantNoServers => _en ? 'No servers to choose from yet. Add a subscription first, then ask me again.' : 'Пока не из чего выбирать. Добавь подписку с серверами и спроси меня ещё раз.';
  static String assistantServerRecommendation(String name) => _en ? 'I recommend “$name” ✨ Find it in your server list and connect!' : 'Советую «$name» ✨ Найди его в списке серверов и подключайся!';
  static String get assistantTitle => _en ? 'AI assistant' : 'ИИ помощник';
  static String get assistantGreeting => _en ? 'Hi! I’m your Flux assistant. How can I help?' : 'Привет! Я твой помощник в Flux. С чем помочь?';
  static String get assistantPlaceholder => _en ? 'Ask me something…' : 'Напиши что-нибудь…';
  static String get assistantSend => _en ? 'Send message' : 'Отправить сообщение';
  static String get assistantClose => _en ? 'Close assistant' : 'Закрыть помощника';
  static String get assistantTyping => _en ? 'Thinking…' : 'Думаю…';
  static String get assistantFallback => _en ? 'I can’t do that yet 😅 Try one of the questions below.' : 'Я такое ещё не умею 😅 Попробуй один из вопросов снизу.';
  static List<({String question, List<String> answers})> get assistantPrompts => _en ? [
    (question: 'How do I connect?', answers: [
      'Pick a server and turn on Proxy or TUN. You’ve got this. I believe in you more than in public Wi-Fi.',
      'Add a subscription, pick a server, then connect. Three steps. I spent 650 milliseconds thinking about this.',
      'Choose a server and a connection mode. If it doesn’t work, try another server. My entire training paid off.',
    ]),
    (question: 'Motivate me', answers: [
      'You opened a VPN and found a habit tracker. At this point, anything is possible. Start small.',
      'One tiny step today beats a perfect plan tomorrow. Tick off a habit. I’ll be proud.',
      'Your streak won’t build itself. Unless someone asks for that in the comments too.',
    ]),
    (question: 'Tell me a joke', answers: [
      'A VPN, a habit tracker and an AI walk into a bar. The bartender says: “Another feature request?”',
      'This used to be a VPN. Then we opened the comments.',
      'My neural network has three layers: a button, a random number and confidence.',
    ]),
  ] : [
    (question: 'Как подключиться?', answers: [
      'Выбери сервер и включи Proxy или TUN. Ты справишься. Я верю в тебя больше, чем в публичный Wi-Fi.',
      'Добавь подписку, выбери сервер и подключись. Всего три шага. Я думал об этом целых 650 миллисекунд.',
      'Выбери сервер и режим подключения. Не получилось — попробуй другой сервер. Не зря меня обучали.',
    ]),
    (question: 'Дай мотивацию', answers: [
      'Ты открыл VPN и нашёл трекер привычек. Значит, возможно вообще всё. Начни с малого.',
      'Один маленький шаг сегодня лучше идеального плана на завтра. Отметь привычку — я буду гордиться.',
      'Серия привычек сама себя не сделает. Если только в комментариях не попросят и это.',
    ]),
    (question: 'Расскажи шутку', answers: [
      'Заходят как-то VPN, трекер привычек и ИИ в бар. Бармен: «Опять фичу в комментариях попросили?»',
      'Раньше это был просто VPN. А потом мы открыли комментарии.',
      'У моей нейросети три слоя: кнопка, рандом и уверенность в себе.',
    ]),
  ];
  // Habit tracker
  static String get habitsTitle => _en ? 'Habits' : 'Привычки';
  static String get habitsSubtitle => _en ? 'Requested in the comments. Built into a VPN.' : 'Просили в комментариях. Сделали в VPN.';
  static String get habitsEmpty => _en ? 'Your first habit starts here. Progress stays on this device.' : 'Начни с первой привычки. Прогресс хранится на этом устройстве.';
  static String get habitsPlaceholder => _en ? 'New habit (up to 80 characters)' : 'Новая привычка (до 80 символов)';
  static String get habitsAdd => _en ? 'Add habit' : 'Добавить привычку';
  static String get habitsDelete => _en ? 'Delete habit and history?' : 'Удалить привычку и историю?';
  static String get habitsRetry => _en ? 'Retry' : 'Повторить';
  static String get habitsLoading => _en ? 'Loading habits…' : 'Загружаем привычки…';
  static String get habitsLoadError => _en ? 'Could not load habits. Your file has been preserved.' : 'Не удалось загрузить привычки. Файл сохранён без изменений.';
  static String get habitsSaveError => _en ? 'Could not save. Please try again.' : 'Не удалось сохранить. Попробуй ещё раз.';
  static String habitsProgress(int done, int total) => _en ? 'Today: $done / $total' : 'Сегодня: $done / $total';
  static String habitsStreak(int count) => _en ? 'Current streak: $count days' : 'Серия: $count дн. подряд';
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

  // home_tiles/home_tile_grid.dart
  static String get customizeTiles => _en ? 'Customize' : 'Настроить';
  static String get doneCustomizingTiles => _en ? 'Done' : 'Готово';
  static String get addTile => _en ? 'Add tile' : 'Добавить плитку';
  static String get removeTile => _en ? 'Remove' : 'Удалить';
  static String get tileSizeSmall => _en ? 'Small' : 'Маленькая';
  static String get tileSizeWide => _en ? 'Wide' : 'Широкая';
  static String get tileSizeLarge => _en ? 'Large' : 'Большая';
  static String get tileRadiusSharp => _en ? 'Sharp corners' : 'Острые углы';
  static String get tileRadiusRounded => _en ? 'Rounded corners' : 'Скруглённые углы';
  static String get tileRadiusPill => _en ? 'Pill' : 'Таблетка';
  static String get tileTypeServerInfo => _en ? 'Server (icon + name + status)' : 'Сервер (иконка + имя + статус)';
  static String get tileTypeServerIcon => _en ? 'Server icon' : 'Иконка сервера';
  static String get tileTypeServerStatus => _en ? 'Server name + status' : 'Имя сервера + статус';
  static String get tileTypeModeSelector => _en ? 'Off/Proxy/TUN switch' : 'Переключатель Off/Proxy/TUN';
  static String get tileTypeRoutingPreset => _en ? 'Routing preset' : 'Пресет роутинга';
  static String get tileTypeVariantSelector => _en ? 'Connection variant' : 'Вариант подключения';
  static String get tileWidthLabel => _en ? 'Width' : 'Ширина';
  static String get tileRadiusStyleLabel => _en ? 'Corner style' : 'Скругление';
  static String get tileAlignLabel => _en ? 'Content alignment' : 'Расположение';
  static String get tileAlignStart => _en ? 'Left' : 'Слева';
  static String get tileAlignCenter => _en ? 'Center' : 'По центру';
  static String get tileAlignEnd => _en ? 'Right' : 'Справа';
  static String get resetTilesToDefault => _en ? 'Reset' : 'Сбросить';

  // app/tray.dart
  static String get trayOpen => _en ? 'Open' : 'Открыть';
  static String get trayDisconnect => _en ? 'Disconnect' : 'Отключить';
  static String get trayConnect => _en ? 'Connect' : 'Подключить';
  static String get trayExit => _en ? 'Exit' : 'Выход';
  static String get trayStatusConnected => _en ? 'Connected' : 'Подключено';
  static String get trayStatusConnecting => _en ? 'Connecting…' : 'Подключение…';

  // app/connection_notifications.dart — трек 25
  static String get notificationConnectedTitle =>
      _en ? 'Connected' : 'Подключено';
  static String notificationConnectedBody(String serverName, ConnectionMode mode) {
    final modeLabel = mode == ConnectionMode.tun ? 'TUN' : (_en ? 'Proxy' : 'Прокси');
    return '$serverName — $modeLabel';
  }

  static String get notificationDisconnectedTitle =>
      _en ? 'Disconnected' : 'Отключено';
  static String get notificationErrorTitle =>
      _en ? 'Connection error' : 'Ошибка подключения';
  static String get notificationGeoAssetsFailedTitle => _en
      ? 'Failed to download routing databases'
      : 'Не удалось скачать базы роутинга';
  static String get showNotificationsLabel =>
      _en ? 'Show notifications' : 'Показывать уведомления';

  // server_list_panel.dart
  static String get cannotPingInTun =>
      _en ? "Can't ping in TUN mode" : 'Нельзя пинговать в TUN-режиме';
  static String get pingBlocksTunDescription => _en
      ? 'Measuring latency conflicts with an active TUN connection — disconnect or switch to Proxy to ping.'
      : 'Измерение задержки мешает активному TUN-соединению — отключитесь или переключитесь на Proxy, чтобы пинговать.';
  static String get servers => _en ? 'Servers' : 'Серверы';
  static String get noServersYet =>
      _en ? 'No servers yet — add a subscription or a link.' : 'Пока нет серверов — добавьте подписку или ссылку.';

  // server_row.dart
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
  static String get presetNameLabel => _en ? 'Preset name' : 'Название пресета';
  static String get presetNamePlaceholder =>
      _en ? 'e.g. Gaming mode' : 'например, Gaming mode';
  static String get defaultOutboundLabel =>
      _en ? 'Other traffic' : 'Остальной трафик';

  // import_routing_preset_dialog.dart / routing_preset_exchange.dart
  static String get importPresetLabel =>
      _en ? 'Import from link' : 'Импортировать по ссылке';
  static String get presetLinkPlaceholder =>
      _en ? 'https://...' : 'https://...';
  static String get importPresetFailed =>
      _en ? 'Could not import:' : 'Не удалось импортировать:';
  static String get presetExportedToClipboard =>
      _en ? 'Preset copied to clipboard' : 'Пресет скопирован в буфер обмена';
  static String get importFromClipboardLabel =>
      _en ? 'Import from clipboard' : 'Импортировать из буфера';
  static String get presetClipboardEmpty =>
      _en ? 'Clipboard is empty' : 'Буфер обмена пуст';
  static String get presetImportedFromClipboard =>
      _en ? 'Preset imported' : 'Пресет импортирован';

  // settings_page.dart — секция "Роутинг"
  static String get activeRoutingLabel => _en ? 'Active routing' : 'Активный роутинг';
  static String get serverRoutingPreset => _en ? 'Server routing' : 'Роутинг сервера';
  static String get serverRoutingPresetDescription => _en
      ? 'Each server uses its own routing, if it has one — same as before.'
      : 'Каждый сервер использует свой роутинг, если он есть — как и раньше.';
  static String get createPresetLabel => _en ? 'Create preset' : 'Создать пресет';

  // settings_page.dart — навигация секций
  static String get sectionPersonalization => _en ? 'Personalization' : 'Персонализация';
  static String get sectionPing => _en ? 'Ping' : 'Пинг';
  static String get sectionSubscription => _en ? 'Subscription' : 'Подписка';
  static String get sectionRoutingPresets => _en ? 'Routing' : 'Роутинг';
  static String get sectionRouting => _en ? 'Routing databases' : 'Базы роутинга';
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
  static String get backgroundCustomVideo => _en ? 'Custom video' : 'Своё видео';
  static String get chooseVideoFileLabel => _en ? 'Choose file…' : 'Выбрать файл…';
  static String get changeVideoFileLabel => _en ? 'Change file…' : 'Заменить файл…';
  static String get removeVideoFileLabel => _en ? 'Remove' : 'Убрать';
  static String get noVideoFileSelected =>
      _en ? 'No video selected yet' : 'Видео ещё не выбрано';
  static String videoImportFailure(Object error) => _en
      ? 'Could not import video: $error'
      : 'Не удалось импортировать видео: $error';

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

  // settings_page.dart — базы роутинга (geoip/geosite)
  static String get geoipUrlLabel => _en ? 'geoip.dat URL' : 'Ссылка на geoip.dat';
  static String get geositeUrlLabel => _en ? 'geosite.dat URL' : 'Ссылка на geosite.dat';
  static String get updateGeoAssetsLabel =>
      _en ? 'Update routing databases' : 'Обновить базы роутинга';
  static String get geoAssetsUpdateSuccess =>
      _en ? 'Routing databases updated' : 'Базы роутинга обновлены';
  static String geoAssetsUpdateFailure(Object error) => _en
      ? 'Failed to update routing databases: $error'
      : 'Не удалось обновить базы роутинга: $error';

  // settings_page.dart — подписка/система
  static String get autoGroupLabel =>
      _en ? 'Automatically split into groups' : 'Автоматическая разбивка по группам';
  static String get autoStartLabel =>
      _en ? 'Start with Windows' : 'Запускать при старте Windows';

  // settings_page.dart — автозапуск/автоподключение (трек 24)
  static String get autoStartPrivilegeLabel =>
      _en ? 'Start automatically as' : 'Автозапускать как';
  static String get autoStartPrivilegeNone => _en ? 'Off' : 'Выключено';
  static String get autoStartPrivilegeStandard => _en ? 'Regular' : 'Обычный';
  static String get autoStartPrivilegeElevated =>
      _en ? 'With administrator rights' : 'С правами администратора';
  static String get autoStartShowWindowLabel =>
      _en ? 'Show window on autostart' : 'Показывать окно при автозапуске';
  static String get autoConnectOnStartupLabel =>
      _en ? 'Connect automatically on startup' : 'Автоматически подключаться при запуске';
  static String get autoConnectModeLabel =>
      _en ? 'Autoconnect method' : 'Режим при автоподключении';
  static String get elevatedAutoStartConfirmed =>
      _en
          ? 'Administrator autostart registered'
          : 'Автозапуск с правами администратора зарегистрирован';
  static String get elevatedAutoStartDeclined => _en
      ? "Administrator autostart wasn't confirmed — UAC request may have been declined"
      : 'Автозапуск с правами администратора не подтверждён — возможно, запрос UAC был отклонён';

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

  // onboarding_flow.dart / onboarding_steps.dart
  static String get onboardingWelcomeTitle =>
      _en ? 'Welcome to Flux' : 'Добро пожаловать в Flux';
  static String get onboardingWelcomeSubtitle => _en
      ? "Want to set a few things up, or just get started with the recommended defaults?"
      : 'Хочешь кое-что настроить, или сразу начать с рекомендованными параметрами?';
  static String get onboardingCustomize => _en ? 'Customize' : 'Настроить';
  static String get onboardingSkip => _en ? 'Skip' : 'Пропустить';
  static String get onboardingBackgroundTitle =>
      _en ? 'Pick a background' : 'Выбери фон';
  static String get onboardingLanguageTitle =>
      _en ? 'Pick a language' : 'Выбери язык';
  static String get onboardingAutostartTitle =>
      _en ? 'Launch on Windows startup?' : 'Запускать при старте Windows?';
  static String get onboardingAutostartCaption => _en
      ? 'Flux will start minimized to the tray when Windows boots — you can change this later in Settings.'
      : 'Flux будет запускаться свёрнутым в трей при загрузке Windows — это всегда можно поменять в настройках.';
  static String get onboardingGuideTitle =>
      _en ? 'Grouping and reordering' : 'Группировка и сортировка';
  static String get onboardingGuideCaption => _en
      ? 'Servers can be grouped into folders — tap the group below to expand it. You can also drag any row to reorder the list. Try it out!'
      : 'Серверы можно группировать в папки — тапни по группе ниже, чтобы развернуть. А ещё любую строку можно перетащить, чтобы поменять порядок. Попробуй!';
  static String get onboardingBack => _en ? 'Back' : 'Назад';
  static String get onboardingNext => _en ? 'Next' : 'Далее';
  static String get onboardingDone => _en ? 'Get started' : 'Готово';

  // settings_page.dart — кнопка в разделе "О программе"
  static String get redoOnboardingLabel =>
      _en ? 'Redo initial setup' : 'Пройти настройку заново';
}

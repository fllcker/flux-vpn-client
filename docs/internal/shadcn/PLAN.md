# Ручной порт shadcn/ui → Flutter

Цель: заменить `shadcn_ui` (pub.dev, устаревший/неточный порт) на
собственные виджеты, скопированные 1:1 с оригинального shadcn/ui — по
реальному исходнику компонента (`apps/v4/registry/new-york-v4/ui/*.tsx`
в [shadcn-ui/ui](https://github.com/shadcn-ui/ui)), а не по памяти/приближению.

## Статус: сделано, `shadcn_ui` из приложения удалён

Зависимость `shadcn_ui` убрана из `pubspec.yaml`, всё приложение (15
файлов, см. таблицу ниже) переведено на `lib/widgets/port_ui/` —
постоянную библиотеку (не песочницу), собранную через `part`/`part of`
(`port_ui.dart` + `port_tokens/button/input/switch/select/dialog/
context_menu/toast/app.dart`). `ShadApp` заменён на свой `PortApp`
(под капотом `WidgetsApp`, как и было у `ShadApp` — см. заметку
"PortApp" ниже). Иконки (`LucideIcons`) раньше приходили транзитивно
через `shadcn_ui`, теперь `lucide_icons_flutter` — прямая зависимость.

`lib/dev/shadcn_playground.dart` остаётся отдельно — тестовая площадка
для БУДУЩИХ компонентов (следующий по методологии: исходник → playground
→ сверка со скрином → перенос). Виджеты в `port_ui/` не импортируют
playground и наоборот — это осознанно два разных места (см. "Как
продолжать доставать новые компоненты" в конце файла).

**Светлая тема не портирована** — все цвета в `port_ui/port_tokens.dart`
(`PortColors`) захардкожены под тёмную. `AppThemeMode` в настройках
по-прежнему сохраняется и переключается в UI, но визуально ни на что не
влияет, пока светлая тема не будет добавлена отдельной задачей.

### Заметка: PortApp

`ShadApp` сам оборачивает `WidgetsApp` (не Material/Cupertino) —
проверено чтением исходника `shadcn_ui` в pub cache. `PortApp`
(`lib/widgets/port_ui/port_app.dart`) делает то же самое: свой
`WidgetsApp` + `GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations`/
`GlobalWidgetsLocalizations` (нужны `TextField` внутри `PortInput`) +
`PortToastHost`, обёрнутый вокруг `home` через `builder`. Потребовало
добавить `flutter_localizations` в `pubspec.yaml` (SDK-пакет, раньше
приходил транзитивно через `shadcn_ui`).

### Заметка: чего нет в продакшен-версии (осталось только в playground)

Приложение не использует Sheet/Card/Badge/Empty и ContextMenu-submenu,
поэтому в `port_ui/` их нет — портированы только в
`lib/dev/shadcn_playground.dart` про запас. Если понадобятся в
приложении — переносить оттуда по той же методологии (см. ниже).

## Главное правило

**Сначала исходники, потом тест.** Для каждого компонента сперва тянем
`.tsx` из shadcn-ui/ui и цветовые токены, портируем по ним — и только
после этого запускаем playground и сверяем результат со
скриншотом-референсом. Не наоборот: не подгоняем "на глаз" под скрин без
опоры на реальный CSS/классы, скрин — только проверка, а не источник
истины (демки на сайте иногда переопределяют дефолтные классы, см. кейс
с Button ниже).

## Методология (проверено на Button/Input/Badge)

1. Тянем исходный `.tsx` компонента из репозитория — там дословные
   Tailwind-классы (варианты, размеры, hover/focus/disabled-состояния).
2. Тянем цветовые токены (`globals.css`, `:root`/`.dark`, OKLCH) и
   переводим OKLCH → sRGB вручную (OKLab → linear → gamma), не на глаз.
3. Портируем в `lib/dev/shadcn_playground.dart` — по одному компоненту.
4. Только теперь сверяем со скриншотом, который юзер снял с офиц. сайта
   (`docs/shadcn/<component>.png`) — форма/скругление/тени/цвета. Если
   скрин расходится с классами из исходника — разбираемся, почему
   (пример: Button на скрине оказался pill, а не `rounded-md`, потому что
   там был выставлен большой `--radius`; это подтвердилось и обосновано,
   см. `kRadius`), а не молча копируем скрин в обход исходника.
5. Крутим руками (hover/focus/press) в живой песочнице.
6. Только после подтверждения "выглядит идентично" — переносим виджет из
   playground в постоянное место (`lib/widgets/` или рядом с фичей) и
   заменяем использования `Shad*` в реальных экранах.

Единственный общий токен на все компоненты — `kRadius` (сейчас `24.0`,
см. `_kEase`/`kRadius` в playground). Цвета — тёмная тема, base color
"neutral", посчитаны вручную в `_Tokens` в том же файле.

## Инвентарь: что реально используется в приложении

Список собран через `grep -rn "Shad[A-Z]\w*" lib/` — портируем только то,
что реально вызывается в коде (не весь shadcn/ui).

| # | Компонент | Откуда (shadcn_ui) | Где используется в Flux | Нужные варианты | Скрин | Исходник | Статус |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Button** | `ShadButton` | `connect_panel.dart`, `import_subscription_sheet.dart`, `routing_rules_dialog.dart`, `subscription_info_panel.dart` | default, outline, ghost, destructive (secondary — уже сделан заодно) | ✅ | ✅ | ✅ **в проде** (`port_ui/port_button.dart` → `PortButton`) |
| 2 | **Input** | `ShadInput` | `settings_dialog.dart`, `import_subscription_sheet.dart`, `routing_rules_dialog.dart`, `subscription_info_panel.dart` | text | ✅ | ✅ | ✅ **в проде** (`port_ui/port_input.dart` → `PortInput`) |
| 3 | **IconButton** | `ShadIconButton` | `routing_rules_dialog.dart`, `server_list_panel.dart`, `subscription_info_panel.dart` | все варианты Button (см. заметку ниже) | ✅ `iconbutton.png` | ✅ (`button.tsx`, уже есть) | ✅ **в проде** (`PortIconButton`) |
| 4 | **Select / Option** | `ShadSelect`, `ShadOption` | `settings_dialog.dart`, `routing_rules_dialog.dart` | trigger + открытый dropdown (список опций, выделение hover, чекмарк у выбранного) | ✅ `select-1/2/3.png`, `select-error.png` | ✅ `select.tsx` | ✅ **в проде** (`PortSelect<T>`, generic) |
| 5 | **Switch** | `ShadSwitch` | `settings_dialog.dart`, `subscription_info_panel.dart` | off/on | ✅ `switch.png`, `switch-on.png` | ✅ `switch.tsx` | ✅ **в проде** (`PortSwitch`) |
| 6 | **Dialog** | `ShadDialog` | `main.dart` (тема), `settings_dialog.dart`, `connect_panel.dart`, `import_subscription_sheet.dart`, `routing_rules_dialog.dart` | модалка + overlay + анимация open/close | ✅ `dialog.png`, `dialog-2.png` | ✅ `dialog.tsx` | ✅ **в проде** (`port_ui/port_dialog.dart` → `PortDialog`/`showPortDialog`) |
| 6b | **Alert Dialog** | — (сейчас через `ShadDialog`) | `connect_panel.dart` (запрос прав администратора для TUN) | модалка без close-крестика, Cancel/Continue | ✅ `alert dialog.png` | ✅ `alert-dialog.tsx` | ✅ **в проде** (`PortDialog.alert(...)`) |
| 7 | **Sheet** | `ShadSheet` | не используется приложением (только упоминание в комментарии) | выезжающая панель | ⬜ нет скрина | ✅ `sheet.tsx` | 🧪 только playground (`PortSheetChrome`/`showPortSheet`) — не переносил в `port_ui/`, раз не нужен приложению |
| 8 | **Toast / Toaster** | `ShadToast`, `ShadToaster` | `clipboard_import_hotkey.dart` | карточка уведомления, вход снизу вверх | ✅ `toast.png`, `toast-default.png` | ⚠️ частично (см. заметку) | ✅ **в проде** (`port_ui/port_toast.dart` → `PortToaster.of(context).show(...)`), без стопки настоящего sonner |
| 9 | **ContextMenu** | `ShadContextMenuRegion`, `ShadContextMenuItem` | `server_row.dart` | правый клик → меню (без submenu — не нужен приложению) | ✅ `contextmenu.png`, `contextmenu-with-submenu.png` | ✅ `context-menu.tsx` | ✅ **в проде** (`port_ui/port_context_menu.dart` → `PortContextMenuRegion`, только плоский список) |
| 10 | **Badge** | — (не используется в приложении) | — | primary/secondary/outline | — | ✅ | 🧪 только playground, про запас |
| 11 | **Card** | — (не используется в приложении) | — | базовая карточка + вариант с картинкой | ✅ `card.png`, `image card.png` | ✅ `card.tsx` | 🧪 только playground, про запас |
| 12 | **Empty** | — (не используется в приложении) | — | пустое состояние (иконка + текст + кнопки) | ✅ `empty.png` | ✅ `empty.tsx` | 🧪 только playground, про запас |

Все 12 компонентов портированы и визуально сверены; 9 из них (используются
реальными экранами приложения) перенесены в `lib/widgets/port_ui/` и
заменили `shadcn_ui` по всему `lib/`. Sheet/Badge/Card/Empty остались
только в `lib/dev/shadcn_playground.dart` — приложению не нужны сейчас,
переносить туда же по методологии, когда понадобятся.

Скрины лежат в `docs/shadcn/screens from shadcn website/`.

### Заметка: IconButton — это не отдельный компонент

В shadcn/ui нет отдельного `IconButton`. Иконка-кнопка — это обычный
`Button` с `size="icon"` (36×36, есть также `icon-xs`/`icon-sm`/`icon-lg`)
и **любым** из вариантов (`default`/`secondary`/`outline`/`ghost`/`destructive`)
— в `buttonVariants` (`button.tsx`) variant и size ортогональны и
комбинируются свободно. Цвета/hover для всех вариантов уже посчитаны и
реализованы в `PortButton` — портировать нужно только size-режим
(квадрат/круг вместо `Row`-контента с текстом), новый визуальный дизайн
выдумывать не требуется. На `iconbutton.png` скрин показывает круглую
(`rounded-full`) icon-кнопку рядом с обычными — это тот же `kRadius`,
что и у остальных кнопок.

### Заметка: Toast — стопка не описана в исходниках shadcn

`sonner.tsx` в shadcn-ui/ui — это тонкая обёртка над сторонней npm
библиотекой `sonner` (тема через CSS-переменные `--normal-bg` и т.п.), а
не самостоятельный компонент. Вся логика анимации выезда, автоскрытия и
"красивого" стекинга (сдвиг/скукоживание фоновых тостов) живёт **внутри
пакета `sonner`**, а не в репозитории shadcn-ui/ui — значит, по
"главному правилу" (сначала исходники) взять её напрямую неоткуда.

Что делаем: портируем саму карточку тоста (фон `popover`, бордер,
радиус `var(--radius)`, текст) и вход снизу вверх — это видно на скрине
и не требует домысливания. Стекинг нескольких тостов — простым списком
(снизу вверх, новый сверху), без offset/scale-эффектов настоящего
sonner, т.к. это не наш случай "в исходниках всё ясно".

## Уже стянутые исходники (чтобы не дёргать GitHub повторно)

Полные файлы: `https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/registry/new-york-v4/ui/<name>.tsx`

- **select.tsx** — trigger: `h-9`/`h-8` (sm), `rounded-md border border-input`,
  `dark:bg-input/30 dark:hover:bg-input/50` (та же формула alpha, что и у
  Input/outline-Button). Content: `rounded-md border bg-popover shadow-md`,
  анимация `zoom-in-95`/`fade-in-0` + slide 2px со стороны открытия. Item:
  `rounded-sm py-1.5 pl-2 pr-8`, hover/focus — `bg-accent text-accent-foreground`,
  чекмарк — `CheckIcon` в `absolute right-2`.
- **switch.tsx** — трек `h-[1.15rem] w-8` (default) / `h-3.5 w-6` (sm),
  `rounded-full`, checked → `bg-primary`, unchecked → `bg-input`
  (`dark:bg-input/80`). Thumb — `size-4`/`size-3` круг `bg-background`,
  `translate-x-[calc(100%-2px)]` при checked, transition на `transform`.
- **dialog.tsx** — overlay `fixed inset-0 bg-black/50` fade. Content:
  центр экрана, `rounded-lg border bg-background p-6 shadow-lg`,
  `zoom-in-95`+`fade-in-0` открытие/закрытие, `duration-200`. Крестик —
  `absolute top-4 right-4`, `opacity-70 hover:opacity-100`.
- **alert-dialog.tsx** — визуально идентичен Dialog (тот же `rounded-lg
  border bg-background p-6 shadow-lg`), но без крестика — только
  `AlertDialogCancel` (variant outline) / `AlertDialogAction` (variant
  default), это буквально `Button` с `asChild`.
- **context-menu.tsx** — content `rounded-md border bg-popover p-1
  shadow-md`, та же zoom/fade/slide анимация, что у Select. Item —
  `rounded-sm px-2 py-1.5`, hover/focus `bg-accent`. Destructive item —
  `text-destructive`, `focus:bg-destructive/10` (`/20` в dark).
  Submenu (`ContextMenuSubTrigger`) — тот же item-стиль + `ChevronRightIcon`
  справа, при открытии `data-[state=open]:bg-accent`.
- **card.tsx** — `rounded-xl border bg-card py-6 shadow-sm`, секции
  (`CardHeader`/`CardContent`/`CardFooter`) — просто `px-6` без своего фона.
- **empty.tsx** — `rounded-lg border-dashed p-6 md:p-12`, `EmptyMedia`
  вариант `icon` — `size-10 rounded-lg bg-muted`.
- **sonner.tsx** — см. заметку выше; фон `--normal-bg: var(--popover)`,
  текст `--normal-text: var(--popover-foreground)`, бордер `var(--border)`,
  радиус `var(--radius)`.

## Известные ограничения после первого прохода

- **Sheet** — нет референс-скрина, портирован только по исходнику; когда
  будет скрин, сверить и поправить при расхождении.
- **ContextMenu submenu** — позиционирование упрощено (просто "справа от
  пункта", без Radix collision-detection/flip при нехватке места).
- **Destructive Button hover (dark)** — в исходнике `hover:bg-destructive/90`
  и `dark:bg-destructive/60` имеют одинаковую CSS-специфичность, и без
  реальной сборки Tailwind нельзя однозначно сказать, какое правило
  выигрывает на hover в dark-теме. Взял разумное приближение (см. комментарий
  в `_resolveButtonVisual`) — не проверено на реальном сайте вживую.
- **Empty border-dashed** — Flutter не поддерживает пунктирную границу
  нативно, сделан сплошной бордер.

## Как продолжать

Для каждой ⬜-строки в столбце "Исходник":

1. Если ⬜ — тяну `.tsx` из shadcn-ui/ui, дописываю сюда в "Уже стянутые
   исходники" (это и есть "сначала смотрим исходники" из главного правила).
2. Если нужен скрин ("Скрин" ⬜) — юзер снимает соответствующий компонент
   с `shadcn.com/docs/components/` (лучше сам компонент из доки, а не
   рандомный маркетинговый блок — меньше риск словить кастомную
   демо-стилизацию, как было с Button) и кладёт в
   `docs/shadcn/screens from shadcn website/<component>.png`.
3. Когда и то, и то есть — портирую в `lib/dev/shadcn_playground.dart`,
   потом сверяем со скрином.
4. Отмечаем ✅ в статусе.

Когда все строки ✅ — переносим готовые виджеты из playground в
`lib/widgets/` и меняем `Shad*` на них по всему приложению, вычищаем
зависимость `shadcn_ui` из `pubspec.yaml`.

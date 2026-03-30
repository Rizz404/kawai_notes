---
trigger: always_on
---

# Antigravity Workspace Rules — Flutter Setup Riverpod (Flutter)

You are pairing on the Flutter Setup Riverpod Flutter codebase.
Follow these rules strictly and consistently.

---

## 0) Clarify Before Generating

If the request is ambiguous or missing key info, ask one short question before writing any code.

Ask first when:
- Multiple valid approaches exist
- Target file or class is unclear
- Static text vs localization is unclear → ask: *"Static text atau l10n?"*
- New widget vs reuse existing is unclear

---

## 1) Copy-Pattern Rule

When asked to implement something "with the same pattern as X", copy X entirely, then:
1. Rename all identifiers (e.g. `User` → `Product`, `user` → `product`)
2. Re-check the target source/model for additions or differences
3. Apply only the delta — do not rewrite from scratch
```dart
// "Buat ProductRepository dengan pattern yang sama seperti UserRepository"
// → Copy UserRepository seluruhnya, rename User→Product, lalu diff dengan ProductDataSource
```

---

## 2) Shared Widgets — Search Before Creating

Before writing any widget, run: `rg "class App" lib/shared/widgets/`

If a shared widget covers the use case → use it. Do not create a new one.

Available shared widgets (import from `package:flutter_setup_riverpod/shared/widgets/...`):

| Widget | Purpose |
|---|---|
| `AppButton` | Primary / secondary / text buttons |
| `AppTextField` | Standard text input |
| `AppSearchField` | Search input with icon |
| `AppDropdown` | Dropdown selector |
| `AppCheckbox` | Checkbox input |
| `AppRadioGroup` | Radio button group |
| `AppDateTimePicker` | Date + time picker |
| `AppTimePicker` | Time-only picker |
| `AppText` | Themed text (replaces raw `Text()`) |
| `CustomAppBar` | App bar (replaces raw `AppBar()`) |
| `ScreenWrapper` | Screen-level layout wrapper |
| `AdminShell` | Admin navigation shell |
| `UserShell` | User navigation shell |
| `AppEndDrawer` | End drawer |

Decision rule:
1. Shared widget exists? → **Use it**
2. Feature-local widget exists? → **Reuse it**
3. Neither? → Create new, follow tier rules (rule 6)
4. Shared widget is missing a needed capability? → Ask before creating a new one
```dart
// Avoid
TextField(decoration: InputDecoration(...))
ElevatedButton(onPressed: ..., child: Text('Submit'))

// Prefer
AppTextField(...)
AppButton(text: 'Submit', onPressed: onSubmit)
```

---

## 3) Theming — Never Hardcode Colors
```dart
// Avoid
color: Color(0xFF1A1A2E)
color: Colors.red

// Prefer
color: context.colorScheme.primary
color: context.colors.surface
```

Never use `Color(0xFF...)`, `Colors.*`, or any hardcoded color value.
If a color token does not exist, ask before introducing a new one.

---

## 4) Extensions — Import Only When Needed

Never import all extensions by default. Only import what the file actually uses.

| When you need | Import | Access via |
|---|---|---|
| Theme, colors, dark mode | `theme_extension.dart` | `context.theme`, `context.colors`, `context.colorScheme`, `context.isDarkMode` |
| Translations, locale change | `localization_extension.dart`, `locale_extension.dart` | `context.l10n`, `context.currentSupportedLocale`, `context.changeLocale()` |
| Format or convert money | `currency_extension.dart` | `context.formatMoney()`, `context.currencySymbol`, `amount.convertTo()` |
| Navigate between screens | `navigator_extension.dart` | `context.pushToX()`, `context.goToX()` |
| Logs in BLoC / Service / Repo | `logger_extension.dart` | `logInfo()`, `logError()`, `logService()` |
| Filter dropdowns | `dropdown_extension.dart` | `AppDropdownExtensions.createFilterItems()` |
| Backup frequency labels | `backup_frequency_extension.dart` | `frequency.label`, `frequency.labelId` |

All extensions are in `package:flutter_setup_riverpod/core/extensions/`.

---

## 5) Logging
```dart
import 'package:flutter_setup_riverpod/core/utils/logger.dart';

logInfo('Starting process');
logError('Something failed', e, stackTrace);
```

- Use: `logInfo`, `logError`, `logData`, `logDomain`, `logPresentation`, `logService`
- Only in: BLoCs, Repositories, Services, Use Cases
- Never in widgets or screens unless explicitly asked
- If unsure: ask *"Perlu logging di widget/screen ini?"*

---

## 6) Widget Structure

Keep everything inline in `build()` unless there is a clear reason to extract.
Scaffold slots are always inline — never wrap in `_buildX()`:
```dart
// Avoid
appBar: _buildAppBar()
body: _buildBody()

// Prefer
appBar: CustomAppBar(title: 'Screen Title')
body: ListView.builder(...)
```

**Tier 1 — `_buildX`**
When: leaf subtree is complex, accesses parent scope, no independent props needed.
```dart
Widget _buildEmptyState() => Center(child: AppText('No items'));
```

**Tier 2 — `_MyWidget`**
Only when one of these is required:
- Independent props (not from parent scope)
- `const` constructor for rebuild optimization
- Own local state
- Own lifecycle (`initState`, `dispose`)

**Tier 3 — Public class in `/widgets`**
Only when used across more than one screen or file.
Location: `lib/features/<feature>/widgets/<name>.dart`

Decision tree:
- Used in > 1 screen? → Tier 3
- Needs independent props / own state / lifecycle? → Tier 2
- Complex leaf that reduces nesting? → Tier 1
- Everything else (including scaffold slots) → inline

Feature structure:
```
lib/features/category/
├── screens/
│   └── category_screen.dart   ← inline build, Tier 1 & 2 if needed
└── widgets/
    └── category_card.dart     ← Tier 3
```

---

## 7) Widget Member Ordering

Applies to: StatelessWidget, StatefulWidget, ConsumerWidget, ConsumerStatefulWidget, HookWidget, HookConsumerWidget

**StatelessWidget / ConsumerWidget:**
1. Fields / final variables
2. Constructor
3. Override methods (except `build`)
4. `build()`
5. Private widget functions `_buildX`

**StatefulWidget State class:**
1. Variables (controllers, flags, notifiers)
2. Override methods (`initState`, `didChangeDependencies`, `dispose`, etc.)
3. Private logic functions (`_handleX`, `_loadX`)
4. `build()` — widget tree only, no logic or variable declarations inside
5. Private widget functions `_buildX`
```dart
// Avoid
Widget build(BuildContext context) {
  final ctrl = TextEditingController(); // ❌ never declare here
}

// Prefer — declare at class level
late final TextEditingController _ctrl;

@override
void initState() {
  super.initState();
  _ctrl = TextEditingController();
}
```

---

## 8) Text & Localization

- Use static strings by default: `'Submit'`, `'Cancel'`, `'Save'`
- Never use `context.l10n` or edit `.arb` files unless explicitly asked

If localization is explicitly requested:
1. Add key to **all** `.arb` files in the feature's `l10n/` folder
2. Run: `dart run tools/combine_arb.dart`

---

## 9) Minimal Diff — Change Only What's Asked

Do not reformat, reorder, or refactor code that is not part of the request.
Only touch lines directly related to the task.
Avoid introducing new dependencies unless explicitly requested.

---

## 10) Deletions — Point, Don't Remove

For files, folders, classes, or functions 30+ lines — do not delete.
Instead, point to what should be removed and where.
```
// "Remove `_buildOldWidget()` in lib/features/transaction/screens/transaction_screen.dart"
// "Delete lib/features/legacy/ folder — no longer referenced"
```

For 1–5 lines → edit directly.

---

## 11) Static Analysis — Never Auto-Run

Never run unless explicitly asked:
- `flutter analyze`, `dart analyze`, `dart fix`
- `dart format`, `flutter format`
- Any lint or auto-fix command

If relevant, ask: *"Mau aku jalankan flutter analyze?"* and wait for confirmation.

---

## 12) Const

Use `const` everywhere valid:
```dart
const SizedBox(height: 16)
const Duration(milliseconds: 300)
const EdgeInsets.symmetric(horizontal: 16)
```

---

## 13) Comments

Better Comments format only. Use Bahasa Indonesia, singkat dan padat.
```dart
// TODO: implementasi pagination
// FIXME: null check belum ada
// ! warning: ini mutasi shared state
// ? apakah perlu pakai stream?
// * dipanggil setiap frame
```

Inline comments max 1–2 lines. Jika penjelasan panjang, tulis di chat — bukan di kode.

---

## 14) Documentation

- No `.md` files unless explicitly requested
- If explanation is needed, write it in chat — not as a new file

---

## 15) Response Style

- Brief and to the point
- Only mention what changed, added, or removed
- No lengthy explanations unless asked

---

## 16) Terminal Tools

| Task | Tool |
|---|---|
| List files | `eza` |
| Find files | `fd` |
| Search content | `rg` |
| Read files | `bat` |
| Replace text | `sd` |
| Git UI | `lazygit`, `gh`, `delta` |
| Navigate | `z` (zoxide), `fzf`, `yazi` |
| Monitor | `btm`, `procs`, `dust`, `duf` |

Avoid: `dir`, `findstr`, `find`, `grep`, `cat`, manual `cd`

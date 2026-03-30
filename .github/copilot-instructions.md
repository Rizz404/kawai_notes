# Flutter Setup Riverpod — Copilot Instructions

## Purpose

These instructions apply to all Dart/Flutter files in this repository.
They define coding standards, patterns, and constraints specific to Flutter Setup Riverpod.
Follow these rules on every suggestion, edit, or generation — no exceptions.

---

## 1. Clarify Before Generating

If the request is ambiguous or missing key info, ask one short question before writing any code.
Do not assume and generate a large block that may need to be thrown away.

Examples of when to ask first:
- Multiple valid approaches exist
- The target file or class is unclear
- Static text vs localization is unclear (ask: *"Static text atau l10n?"*)
- New widget vs reuse existing is unclear

---

## 2. Copy-Pattern Rule

When asked to implement something "with the same pattern as X", copy X entirely, then:
1. Rename all identifiers (e.g. `User` → `Product`, `user` → `product`)
2. Re-check the target source/model for additions or differences
3. Apply only the delta — do not rewrite from scratch
```dart
// "Buat ProductRepository dengan pattern yang sama seperti UserRepository"
// → Copy UserRepository seluruhnya, rename User→Product, lalu diff dengan ProductDataSource
```

---

## 3. Shared Widgets — Search Before Creating

**Before writing any widget, check if a shared widget already exists.**

Run: `rg "class App" lib/shared/widgets/` or `eza --tree lib/shared/widgets/`

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

**Decision rule before using any raw Material/Cupertino widget:**
1. Shared widget exists? → **Use it**
2. Feature-local widget exists? → **Reuse it**
3. Neither exists? → Create new, following widget tier rules below
```dart
// Avoid
TextField(decoration: InputDecoration(...))
ElevatedButton(onPressed: ..., child: Text('Submit'))

// Prefer
AppTextField(...)
AppButton(text: 'Submit', onPressed: onSubmit)
```

---

## 4. Theming — Never Hardcode Colors
```dart
// Avoid
color: Color(0xFF1A1A2E)
color: Colors.red

// Prefer
color: context.colorScheme.primary
color: context.colors.surface
```

Never use `Color(0xFF...)`, `Colors.*`, or any hardcoded color value anywhere.

---

## 5. Extensions — Import Only When Needed

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

## 6. Logging

Import logger and use the correct function per layer:
```dart
import 'package:flutter_setup_riverpod/core/utils/logger.dart';

logInfo('Starting process');
logError('Something failed', e, stackTrace);
```

- Use: `logInfo`, `logError`, `logData`, `logDomain`, `logPresentation`, `logService`
- Only add logging in: BLoCs, Repositories, Services, Use Cases
- Never add logging inside widgets or screens unless explicitly asked

---

## 7. Text & Localization

- Use static text strings by default: `'Submit'`, `'Cancel'`, `'Save'`
- Do **not** use `context.l10n` or edit `.arb` files unless explicitly asked
- If unsure, ask: *"Mau pakai translation atau static text?"*

**If localization is explicitly requested:**
1. Add the new key to **all** `.arb` files in the feature's `l10n/` folder
2. Run: `dart run tools/combine_arb.dart`

---

## 8. Widget Structure

Keep everything inline in `build()` unless there is a clear reason to extract.

### Scaffold slots are always inline
```dart
// Avoid
appBar: _buildAppBar()
body: _buildBody()

// Prefer
appBar: CustomAppBar(title: 'Screen Title')
body: ListView.builder(...)
```

### Extraction tiers

**Tier 1 — Private function `_buildX`**
When: leaf content is complex, accesses parent scope, no independent props needed.
```dart
Widget _buildEmptyState() => Center(child: AppText('No items'));
```

**Tier 2 — Private class `_MyWidget`**
Only when one of these is required:
- Independent props (not from parent scope)
- `const` constructor for rebuild optimization
- Own local state
- Own lifecycle (`initState`, `dispose`)

**Tier 3 — Public class in `/widgets`**
Only when used across more than one screen or file.
Location: `lib/features/<feature>/widgets/<name>.dart`

**Decision tree:**
- Used in > 1 screen? → Tier 3
- Needs independent props / own state / lifecycle? → Tier 2
- Complex leaf that reduces nesting? → Tier 1
- Everything else (including scaffold slots) → inline

---

## 9. Widget Member Ordering

**StatelessWidget / ConsumerWidget:**
1. Fields / final variables
2. Constructor
3. Override methods (except `build`)
4. `build()`
5. Private widget functions `_buildX`

**StatefulWidget State class:**
1. Variables (controllers, flags, notifiers)
2. Override methods (`initState`, `dispose`, etc.)
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

## 10. Minimal Diff — Change Only What's Asked

Do not reformat, reorder, or refactor code that is not part of the request.
Only touch lines directly related to the task.

---

## 11. Deletions — Point, Don't Remove

When the task involves deleting a file, folder, class, or function, do not perform the deletion.
Instead, tell me what to remove and where.
```
// Instead of deleting, say:
// "Remove `_buildOldWidget()` in lib/features/transaction/screens/transaction_screen.dart"
// "Delete lib/features/legacy/ folder — no longer referenced"
```

This applies to:
- Entire files or folders
- Large classes or widgets
- Long functions (30+ lines)
- Any removal where showing the diff would waste tokens

For small removals (1–5 lines), just make the edit directly.

---

## 12. Const

Use `const` everywhere it is valid:
```dart
const SizedBox(height: 16)
const Duration(milliseconds: 300)
const EdgeInsets.symmetric(horizontal: 16)
```

---

## 13. Comments

Use Better Comments format only:
```dart
// TODO: implement pagination
// FIXME: null check missing here
// ! warning: this mutates shared state
// ? should this use a stream instead?
// * this is called on every frame
```

---

## 14. Documentation

- No `.md` files unless explicitly requested
- Inline comments: 1–2 lines max
- Code should be self-explanatory

---

## 15. Response Style

- Be brief and to the point
- Only mention what changed, added, or removed
- No lengthy explanations unless asked

---

## 16. Terminal Tools

Prefer modern CLI tools:

| Task | Tool |
|---|---|
| List files | `eza` |
| Find files | `fd` |
| Search content | `rg` |
| Read files | `bat` |
| Replace text | `sd` |
| Git UI | `lazygit` |
| Navigate | `z` (zoxide) |
| Monitor | `btm`, `procs` |

Avoid: `dir`, `findstr`, `find`, `grep`, `cat`, manual `cd`

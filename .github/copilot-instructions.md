Berikut versi copilot-instructions.md yang diselaraskan dengan guidelines.md:

````markdown
# Flutter Setup Riverpod — Copilot Instructions

## Purpose

These instructions apply to all Dart/Flutter files in this repository.
They define coding standards, patterns, and constraints specific to Flutter Setup Riverpod.
Follow these rules on every suggestion, edit, or generation — no exceptions.

---

## 1. Clarify Before Generating

If the request is ambiguous or missing key info, ask one short question before writing any code.
Do not assume and generate a large block that may need to be thrown away.

Ask first when:

- Multiple valid approaches exist
- Target file or class is unclear
- Static text vs localization is unclear → ask: _"Static text atau l10n?"_
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
````

---

## 3. Shared Widgets — Search Before Creating

**Before writing any widget, check if a shared widget already exists.**

Run: `rg "class App" lib/shared/widgets/`

If a shared widget covers the use case → use it. Do not create a new one.

Available shared widgets (import from `package:kawai_notes/shared/widgets/...`):

| Widget              | Purpose                                |
| ------------------- | -------------------------------------- |
| `AppButton`         | Primary / secondary / text buttons     |
| `AppTextField`      | Standard text input                    |
| `AppSearchField`    | Search input with icon                 |
| `AppDropdown`       | Dropdown selector                      |
| `AppCheckbox`       | Checkbox input                         |
| `AppRadioGroup`     | Radio button group                     |
| `AppDateTimePicker` | Date + time picker                     |
| `AppTimePicker`     | Time-only picker                       |
| `AppText`           | Themed text (replaces raw `AppText()`) |
| `CustomAppBar`      | App bar (replaces raw `AppBar()`)      |
| `ScreenWrapper`     | Screen-level layout wrapper            |
| `AdminShell`        | Admin navigation shell                 |
| `UserShell`         | User navigation shell                  |
| `AppEndDrawer`      | End drawer                             |

Decision rule:

1. Shared widget exists? → **Use it**
2. Feature-local widget exists? → **Reuse it**
3. Neither? → Create new, follow tier rules (rule 8)
4. Shared widget is missing a needed capability? → Ask before creating a new one

```dart
// Avoid
TextField(decoration: InputDecoration(...))
ElevatedButton(onPressed: ..., child: AppText('Submit'))

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

Never use `Color(0xFF...)`, `Colors.*`, or any hardcoded color value.
If a color token does not exist, ask before introducing a new one.

---

## 5. Extensions — Import Only When Needed

Never import all extensions by default. Only import what the file actually uses.

| When you need                 | Import                                                 | Access via                                                                     |
| ----------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Theme, colors, dark mode      | `theme_extension.dart`                                 | `context.theme`, `context.colors`, `context.colorScheme`, `context.isDarkMode` |
| Translations, locale change   | `localization_extension.dart`, `locale_extension.dart` | `context.l10n`, `context.currentSupportedLocale`, `context.changeLocale()`     |
| Format or convert money       | `currency_extension.dart`                              | `context.formatMoney()`, `context.currencySymbol`, `amount.convertTo()`        |
| Navigate between screens      | `navigator_extension.dart`                             | `context.pushToX()`, `context.goToX()`                                         |
| Logs in BLoC / Service / Repo | `logger_extension.dart`                                | `logInfo()`, `logError()`, `logService()`                                      |
| Filter dropdowns              | `dropdown_extension.dart`                              | `AppDropdownExtensions.createFilterItems()`                                    |
| Backup frequency labels       | `backup_frequency_extension.dart`                      | `frequency.label`, `frequency.labelId`                                         |

All extensions are in `package:kawai_notes/core/extensions/`.

---

## 6. Logging

Import logger and use the correct function per layer:

```dart
import 'package:kawai_notes/core/utils/logger.dart';

logInfo('Starting process');
logError('Something failed', e, stackTrace);
```

- Use: `logInfo`, `logError`, `logData`, `logDomain`, `logPresentation`, `logService`
- Only in: BLoCs, Repositories, Services, Use Cases
- Never in widgets or screens unless explicitly asked
- If unsure: ask _"Perlu logging di widget/screen ini?"_

---

## 7. AppText & Localization

- Use static text strings by default: `'Submit'`, `'Cancel'`, `'Save'`
- Do **not** use `context.l10n` or edit `.arb` files unless explicitly asked
- If unsure, ask: _"Mau pakai translation atau static text?"_

**If localization is explicitly requested:**

1. Add the new key to **all** `.arb` files in the feature's `l10n/` folder
2. Run: `dart run tools/combine_arb.dart && flutter gen-l10n`

---

## 8. Widget Structure

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

## 9. Widget Member Ordering

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

## 10. Minimal Diff — Change Only What's Asked

Do not reformat, reorder, or refactor code that is not part of the request.
Only touch lines directly related to the task.
Avoid introducing new dependencies unless explicitly requested.

---

## 11. Deletions — Point, Don't Remove

When the task involves deleting a file, folder, class, or function 30+ lines — do not perform the deletion.
Instead, tell me what to remove and where.

```
// "Remove `_buildOldWidget()` in lib/features/transaction/screens/transaction_screen.dart"
// "Delete lib/features/legacy/ folder — no longer referenced"
```

For 1–5 lines → edit directly.

---

## 12. Static Analysis & Formatting

Never run auto-formatters: `dart format`, `flutter format` — ever.
Never run `flutter analyze`, `dart analyze`, or `dart fix` unless:

- All requested implementations are complete, or
- Explicitly asked to find errors

Do not run analyze after every change or as a default step.
If relevant, ask: _"Mau aku jalankan flutter analyze?"_ and wait for confirmation.

---

## 13. Const

Use `const` everywhere it is valid:

```dart
const SizedBox(height: 16)
const Duration(milliseconds: 300)
const EdgeInsets.symmetric(horizontal: 16)
```

---

## 14. Comments

Use Better Comments format only. Use Bahasa Indonesia, singkat dan padat.

```dart
// TODO: implementasi pagination
// FIXME: null check belum ada
// ! warning: ini mutasi shared state
// ? apakah perlu pakai stream?
// * dipanggil setiap frame
```

Inline comments max 1–2 lines. Jika penjelasan panjang, tulis di chat — bukan di kode.

---

## 15. Documentation

- No `.md` files unless explicitly requested
- If explanation is needed, write it in chat — not as a new file

---

## 16. Response Style

- Brief and to the point
- Only mention what changed, added, or removed
- No lengthy explanations unless asked

---

## 17. Terminal Tools

Primary shell: **PowerShell**. Always use PowerShell-compatible commands.
Never run Linux/bash-only commands (e.g. `rm -rf`, `ls`, `export`, `&&` chaining) — they will error.
Never open interactive or pager tools that cannot be closed by the AI: `bat`, `less`, `neovim`, `micro`, `broot`, `jid`, `glow` (without flags).
To read file content, use `Get-Content` (PowerShell native) or `rg` for search-based reading.

| Task            | Tool                              |
| --------------- | --------------------------------- |
| List files      | `eza`                             |
| Find files      | `fd`                              |
| Search content  | `rg`                              |
| Read files      | `Get-Content` (PowerShell native) |
| Replace text    | `sd`                              |
| JSON processing | `jq`                              |
| Git UI          | `lazygit`, `gh`, `delta`          |
| Navigate        | `z` (zoxide), `fzf`, `yazi`       |
| Monitor         | `btm`, `procs`, `dust`, `duf`     |

Avoid: `bat`, `less`, `neovim`, `micro`, `broot`, `jid`, `glow`, `vi`, `vim`, `nano`, `cat`, `dir`, `findstr`, `find`, `grep`, manual `cd`

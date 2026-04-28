---
paths:
  - "lib/**/*.dart"
---

# Dart & Flutter Patterns

## Theming

Never: `Color(0xFF...)`, `Colors.*`, or any hardcoded color value.
Always: `context.colorScheme.primary`, `context.colors.surface`

If a color token does not exist → ask before introducing a new one.

## Extensions — Import Only What the File Uses

All extensions are in `package:kawai_notes/core/extensions/`

| Need                          | File                                | Access via                                      |
| ----------------------------- | ----------------------------------- | ----------------------------------------------- |
| Theme / colors / dark mode    | `theme_extension.dart`              | `context.theme`, `context.colors`, `context.isDarkMode` |
| Translations / locale         | `localization_extension.dart`       | `context.l10n`, `context.changeLocale()`        |
| Currency format / convert     | `currency_extension.dart`           | `context.formatMoney()`, `amount.convertTo()`   |
| Navigation                    | `navigator_extension.dart`          | `context.pushToX()`, `context.goToX()`          |
| Logging (BLoC / Repo / Svc)   | `logger_extension.dart`             | `logInfo()`, `logError()`, `logService()`       |
| Filter dropdown items         | `dropdown_extension.dart`           | `AppDropdownExtensions.createFilterItems()`     |
| Backup frequency labels       | `backup_frequency_extension.dart`   | `frequency.label`, `frequency.labelId`          |

## Logging

```dart
import 'package:kawai_notes/core/utils/logger.dart';
// Available: logInfo, logError, logData, logDomain, logPresentation, logService
```

Only in: BLoCs, Repositories, Services, Use Cases.
Never in widgets or screens unless explicitly requested.

## Localization

Default: static strings — `'Submit'`, `'Cancel'`, `'Save'`.
If l10n is explicitly requested:
1. Add key to **all** `.arb` files in the feature's `l10n/` folder
2. Run: `dart run tools/combine_arb.dart; flutter gen-l10n`

## Copy-Pattern Rule

When asked "same pattern as X": copy X entirely → rename all identifiers → diff with target source → apply delta only.

## Comments

Better Comments format only. English, max 1–2 lines inline.
Long explanations go in chat — not in code.

```dart
// TODO: implement pagination
// FIXME: missing null check
// ! warning: mutates shared state
// ? is a stream needed here?
// * called every frame
```

## Static Analysis & Formatting

Never run `flutter analyze`, `dart analyze`, `dart fix`, `dart format`, or `flutter format` unless:
- All requested implementations are complete, or
- Explicitly asked

Do not run analyze after every change as a default step.

## Const

Use `const` everywhere it is valid.

```dart
const SizedBox(height: 16)
const Duration(milliseconds: 300)
const EdgeInsets.symmetric(horizontal: 16)
```

## Minimal Diff

Do not reformat, reorder, or refactor code outside the scope of the request.
Only touch lines directly related to the task.
Do not introduce new dependencies unless explicitly requested.

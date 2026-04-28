---
paths:
  - "lib/**/*.dart"
---

# Widget Rules

## Shared Widgets — Use Before Creating

Before writing any widget, run: `rg "class App" lib/shared/widgets/`

Decision: Shared exists? → Use it | Feature-local exists? → Reuse it | Neither? → Create, follow tiers below.

| Widget              | Purpose                             |
| ------------------- | ----------------------------------- |
| `AppButton`         | Primary / secondary / text buttons  |
| `AppTextField`      | Standard text input                 |
| `AppSearchField`    | Search input with icon              |
| `AppDropdown`       | Dropdown selector                   |
| `AppCheckbox`       | Checkbox input                      |
| `AppRadioGroup`     | Radio button group                  |
| `AppDateTimePicker` | Date + time picker                  |
| `AppTimePicker`     | Time-only picker                    |
| `AppText`           | Themed text — never raw `Text()`    |
| `CustomAppBar`      | App bar — never raw `AppBar()`      |
| `ScreenWrapper`     | Screen-level layout wrapper         |
| `AdminShell`        | Admin navigation shell              |
| `UserShell`         | User navigation shell               |
| `AppEndDrawer`      | End drawer                          |

If a shared widget is missing a needed capability → ask before creating a new one.

## Widget Tier System

- **Inline** → scaffold slots + simple subtrees (always preferred)
- **`_buildX()`** → complex leaf subtree that accesses parent scope
- **`_MyWidget`** → needs independent props / `const` / own state / own lifecycle
- **`lib/features/<feature>/widgets/*.dart`** → used in more than one screen or file

Scaffold slots are always inline — never `_buildAppBar()`, never `_buildBody()`.

## Member Ordering — StatelessWidget / ConsumerWidget

1. Fields / final variables
2. Constructor
3. Override methods (except `build`)
4. `build()`
5. `_buildX()` private widget functions

## Member Ordering — StatefulWidget State class

1. Variables (controllers, flags, notifiers)
2. Override methods (`initState`, `didChangeDependencies`, `dispose`, etc.)
3. Private logic functions (`_handleX`, `_loadX`)
4. `build()` — widget tree only, no logic or variable declarations inside
5. `_buildX()` private widget functions

Never declare controllers or variables inside `build()`.

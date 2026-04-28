# Flutter Setup Riverpod — Kawai Notes

## Project

Flutter app (Riverpod) — `package:kawai_notes/`. Shell: **PowerShell only**.

Architecture: `lib/features/<feature>/{screens,widgets,providers}/`
Shared widgets: `lib/shared/widgets/` · Extensions: `lib/core/extensions/`

## Critical Rules

> Full rules live in `.claude/rules/` — load per task context.

- Clarify first when: multiple valid approaches exist, target file unclear, static vs l10n unclear
- **Never hardcode colors** — use `context.colorScheme.x` or `context.colors.x`
- **Never create a new shared widget** without checking first: `rg "class App" lib/shared/widgets/`
- Use `const` everywhere valid
- **Minimal diff** — only touch lines directly related to the request
- Deletions 30+ lines → point out location, do not delete

## Build & Dev Commands

```powershell
flutter run
flutter pub get
dart run tools/combine_arb.dart; flutter gen-l10n  # only when l10n explicitly requested
```

## Rules Reference

@.claude/rules/widgets.md
@.claude/rules/dart-patterns.md
@.claude/rules/tooling.md

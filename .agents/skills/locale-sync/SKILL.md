---
name: locale-sync
description: Sync non-English localizations from the English source and regenerate the Swift accessors. Use when localization keys or strings changed, or a translation is missing/stale.
metadata:
  short-description: Generate other *.lproj translations from en.lproj + regen TKLocales.swift
---

# Sync localizations

English is the single source of truth, hand-edited by devs. Agents generate every
other locale and the Swift accessors. Never hand-edit `TKLocales.swift` (generated).

## Paths
- Source: `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings`
- Targets: `de es id ru tr uk uz zh-Hans` (sibling `*.lproj` dirs under `Locales/`)
- Generated accessors: `LocalPackages/TKLocalize/Sources/TKLocalize/TKLocales.swift` (do not edit)

## Steps
1. **Read** the English source. Note its key set and any keys added/removed/changed
   versus each target locale.
2. **For each target locale**, edit its `Localizable.strings` so its key set matches
   English exactly:
   - Add missing keys with a natural translation for that language.
   - Remove keys no longer in English.
   - Re-translate values whose English text changed.
   - Preserve format specifiers (`%@`, `%d`, `%1$@`, …) and their order; keep the
     `"key" = "value";` syntax and existing comments.
3. **Regenerate accessors only if the key set changed** (keys added/removed):
   ```sh
   make locale   # from repo root — runs swiftgen + swiftformat on TKLocales.swift
   ```
   Value-only edits don't change `TKLocales.swift`; skip this step.
4. **Verify**: `make spm PKG=TKLocalize` (type-check) and, if logic-relevant,
   `make test_tklocalize`.

## Notes
- `make locale` reads the swiftgen config (`LocalPackages/TKLocalize/codegen/swiftgen.yml`);
  keys come from the strings file, so accessors are locale-independent.
- Keep keys identical across locales — a key present in one `*.lproj` but absent in
  another is the usual cause of missing-translation fallbacks at runtime.

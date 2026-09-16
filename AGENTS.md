# Repository Guidelines

## Project Structure & Module Organization
- `Tonkeeper/` — main iOS app source + shared resources.
- `TonkeeperWidget/`, `TonkeeperIntents/` — extension targets.
- `LocalPackages/` — SwiftPM modules, grouped by role:
  - **Domain/infra**: `KeeperCore` (wallet domain — API, controllers, entities), `TKCore` (cross-cutting services — analytics, Firebase, push, formatters), `TronSwift` (Tron chain; hosts `TKCryptoKit` tests), `Ledger` (hardware-wallet transport).
  - **UI**: `TKUIKit` (+`TKUIKitResources`), `TKCoordinator`, `TKScreenKit`, `LightweightCharts` (vendored TradingView fork).
  - **Support**: `TKLocalize` (generated — see Localization Workflow), `TKKeychain`, `TKLogging`, `TKFeatureFlags`, `TKAppInfo` (build-environment checks; a leaf `App`/`KeeperCore`/`TKCore`/`TKFeatureFlags`/`AppUI` all reach, so it stays a package).
  - `App/` — top-level assembly + coordinators (depends on all above); `AppModules/<Pkg>` — App-only feature packages (`AppUI`, `Stories` — a `TKStories` presentation target plus a `Stories` domain target, `SignRaw`, `WalletExtensions`). `AppUI` holds crypto-free product views so they stay previewable — see [SwiftUI Previews](#swiftui-previews); it also owns the `TKLottieWebView` renderer for remote animations and the disconnect-dapp toast.
- `Configurations/` — `.xcconfig` signing/build settings.
- `Tonkeeper.xcodeproj/` — primary Xcode project entry point.

## Build, Test, and Development Commands

### Full app build (xcodebuild, from repo root)
```sh
make compile
```

### Fast per-package SwiftPM build (no full app build)
Type-check the `LocalPackages` modules you touched. Builds against the iOS Simulator SDK, reusing the app-level `Package.resolved` read-only (auto-resolution off; transient copy under `LocalPackages/**/Package.resolved`, gitignored).
```sh
make spm PKG=TKUIKit                       # one module
make spm PKG="TKUIKit TKCore KeeperCore"   # a set of modules
make spm PKG=App                           # App module (fast type-check)
make spm PKG=TKUIKit QUIET=1               # agent-friendly quiet output
```
- `PKG` resolves against both `LocalPackages/<Pkg>/` and `LocalPackages/AppModules/<Pkg>/` — use the bare name (e.g. `make spm PKG=Stories`).
- `make spm PKG=App` = Swift-only type check (no actool/signing/linker/build-phase scripts). Best for App-only Swift changes; first run is expensive (compiles full dep tree).
- `QUIET=1` → `swift build --quiet`; default keeps full progress.
- Fast local checks only. Final correctness goes through `make compile` and `make test_*` (which use `Tonkeeper.xcodeproj`).

### Build strategy for agents
1. Edited `LocalPackages/<X>` → `make spm PKG=X`.
2. Edited `App/` or multiple packages → `make spm PKG=App`.
3. Before declaring done → `make compile QUIET=1` (catches build-phase/linker/signing issues `make spm` misses). `QUIET=1` pipes through `xcbeautify -qq` (errors only, ~0 context on success vs ~445 KB); pass/fail from exit code. Drop `QUIET=1` only to diagnose.
4. Changed tested logic → run the relevant `make test_*`.

### Tests — only via `Makefile` from repo root
- Use `make` targets; do not run package-local tests via `cd LocalPackages/... && xcodebuild` or `swift test`.
- Tests route through `Tonkeeper.xcodeproj` to use the app-level lockfile (`Tonkeeper.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). Some package `Package.resolved` files were removed to prevent standalone resolution becoming the default.
- `make test_all` (alias `make test`) runs every unit-test bundle in one pass via the `TonkeeperUnitTests` scheme; the per-module targets below are for a narrower loop.
```sh
make test_tkcore
make test_keeper_core
make test_wallet_core
make test_core_components
make test_tklocalize
make test_tkuikit
make test_tron_swift
make test_tkcryptokit
```
Specific suite / single method via the generic entrypoint:
```sh
make test_project_scheme SCHEME=WalletCore TEST_ONLY=KeeperCoreTests/TonkeeperDeeplinksParserTests
make test_project_scheme SCHEME=WalletCore TEST_ONLY=KeeperCoreTests/TonkeeperDeeplinksParserTests/testActionParsing
```

## Key Decisions
- **Worktrees**: do refactors / new features in a dedicated worktree. Claude Code's `EnterWorktree` creates them under `.claude/worktrees/<name>`, which is where they actually live; a manual one goes in the same place:
  ```sh
  git worktree add .claude/worktrees/<feature-name> -b <branch-name>
  ```
  **Tear one down once its branch is merged.** Each worktree carries its own in-repo `build/` — 17-33 GB (`DerivedData` + `DerivedData-tests` + `DerivedData-xcode` + `SourcePackages`) — so a dozen stale worktrees is a few hundred GB, and nothing reclaims it automatically. Judge "merged" by `git merge-base --is-ancestor <sha> origin/develop`, never by branch name, and skip any worktree that is dirty or locked:
  ```sh
  git worktree remove .claude/worktrees/<name> && rm -rf .claude/worktrees/<name>
  git worktree prune
  ```
  `git worktree remove` leaves the gitignored `build/` behind, so the `rm -rf` matters: a skipped one becomes an orphan directory that holds tens of GB and no longer appears in `git worktree list`. Sweep the directory listing, not just the git registry. An interrupted removal leaves a half-deleted tree that then reports as dirty — finish it with `rm -rf` rather than treating it as work in progress.
  Firebase config (`Tonkeeper/Resources/Firebase`) is gitignored, so a fresh worktree lacks it and the "Firebase plist" build phase fails (`Firebase plist not found`). `make compile` auto-provisions it (via the `firebase_config` prereq, copying from the main tree — no `make setup`/network), and so does the `post-checkout` hook for a new working tree, local copy only. Provision manually with `make firebase_config`; refresh a stale copy by deleting `Tonkeeper/Resources/Firebase` and rerunning.

  SwiftPM dependency stores are per-worktree and per-package, so a fresh worktree (or a never-built package) starts empty and SwiftPM re-checks-out every repository and re-extracts every binary xcframework out of the global cache (`~/Library/Caches/org.swift.swiftpm`) — no downloads, but it dominates the first build. `scripts/provision_spm_deps.sh <store-dir>` instead clones an already-resolved store with `clonefile(2)` (APFS shared blocks, no extra physical disk) and repoints the absolute paths in `workspace-state.json`; its header covers the source lookup and the concurrency rules. No resolved source → normal SwiftPM resolve.
  - `make compile` / `make test_*` seed `build/SourcePackages` via the `spm_deps` prereq; `make spm PKG=X` seeds `LocalPackages/**/X/.build`; builds started outside `make` (Xcode GUI, bare `xcodebuild`) rely on two background warm-ups instead — the `post-checkout` git hook when a working tree is created, and `.claude/hooks/prewarm-spm-deps.sh` on session start.
  - `workspace-state.json` marks a seeded or resolved store, so re-seed by deleting it or the whole store. A store holding files without that marker belongs to a resolve — neither a source nor a destination — until the directory is removed.
  - Xcode GUI ignores `-derivedDataPath` and resolves its own store into `~/Library/Developer/Xcode/DerivedData/Tonkeeper-<hash>`, keyed by the workspace path: another full store per worktree, orphaned when the worktree goes. `make xcode_derived_data` (also run by `make setup` and the hook) moves it to `build/DerivedData-xcode` and seeds it, leaving a location a developer chose alone; `make` builds are unaffected. Xcode honours the location only from per-user `xcuserdata` workspace settings — the committed `xcshareddata` keys are ignored — so it cannot be set once for everyone, and an open project picks it up on reopen.

## Code Style
- **Formatting**: `make format` runs `swiftformat` over the repo. Everything committed is already formatted at the pinned version, so a run only touches what you changed.
- **Tool versions**: exact versions live in `mise.toml` (swiftformat, swiftgen, swiftlint, xcbeautify); `make setup` installs them. Every call site goes through `scripts/tools/tool.sh`, which execs the mise shim by absolute path — a shim is a self-contained binary, so it works even where `PATH` has neither mise nor its shims, as in a git hook launched from a GUI client. Run make targets from the repo root: the shim picks the version from the `mise.toml` of the current directory. `.swiftformat` repeats the swiftformat pin as `--minversion`, so even a direct `swiftformat` call refuses to run an older binary. When a newer swiftformat enables a rule that rewrites untouched files, add `--disable <rule>` to `.swiftformat` — do not reformat the repo to match a new default.
- **Comments**: Do not add comments without clear necessity. Code should read for itself; names and types carry intent. Write a comment only to explain a non-obvious *why* (a subtle invariant, a workaround, a deliberate deviation) or as a short doc for a public API. Do not narrate *what* the code does, restate the method name, or leave porting/implementation-history notes.

## Concurrency
- Give shared mutable state one explicit isolation domain: an actor, `@MainActor` for UI-owned state, or one lock for synchronous APIs. Do not use the main queue as a generic synchronization mechanism for domain or infrastructure state.
- `@Atomic` guards a single access, not an invariant. Do not use it for read-modify-write, check-then-act, or related fields that must change coherently; keep the invariant under one isolation domain.
- Never hold a lock across `await`.
- For observer fan-out, capture the observer snapshot and perform cleanup inside the isolation domain, then invoke callbacks outside it. Define the callback delivery executor and explicitly hop to `MainActor` at UI boundaries.
- Perform cancel-and-replace under the same isolation domain. Treat cancellation as best effort and verify that an async result still belongs to the current operation or scope before applying it.
- When a continuation is stored beyond its lexical scope, give it one owner and ensure exactly-once completion on every path, including cancellation and teardown. If protected by a lock, take and clear it under the lock, then resume it after releasing the lock.
- When changing shared mutable state, identify applicable concurrency failure modes and add focused deterministic tests for non-obvious cases such as reentrancy, overlapping operations, cancellation, and stale completion. Use TSan selectively when correctness depends on actual thread interleaving; keep it out of the default local feedback loop.

## State invalidation
For derived, cached, or asynchronously loaded state:
- Identify the inputs and lifecycle transitions that affect it. Invalidate it whenever an input changes; refresh eagerly only when required by product behavior. Reset related one-shot and lifecycle guards on the same transitions.
- Include every relevant input in the cache key or scope so a changed scope cannot return stale data.
- On scope changes, cancel obsolete work when useful and prevent obsolete completions from updating the new scope.
- Derive list-item identity from stable domain data, never a fresh `UUID()` per render.

## Colors & Theming (SwiftUI)
Palette colors must react to theme switches (light/dark/deepBlue) at render time. Rules, in order of preference:
- **Default**: themed modifier overloads with `TKColor` tokens — `.foregroundStyle(.textPrimary)`, `.background(.backgroundPage)`, `.fill(.accentBlue)`, `.stroke(.separatorCommon)`, `.strokeBorder(.fieldActiveBorder)`, `.shadow(color: .backgroundOverlayLight, radius: 8)`, `.tint(.accentBlue)`. `TKColor` is also a `View`, so it can be used directly for backgrounds, separators and overlays. No `@Environment` needed; tokens resolve at the rendered node.
- **Configs / view models**: store `TKColor` (or `TKThemedText` for attributed spans), never `Color`/`UIColor`/`AttributedString` with baked palette colors; the rendering view resolves via `.resolve(palette)`.
- **Per-scheme divergence outside the palette**: `TKColor.perTheme(light:dark:deepBlue:)`; for whole-view branching read `@Environment(\.tkResolvedTheme)`.
- **Scrims**: use `.tkScrim(.backgroundPage, edge: .bottom)` for the standard 16-stop page fade instead of rebuilding the easing profile and reading the palette manually.
- **`@Environment(\.tkPalette)`** only where a raw `Color` value is genuinely needed: gradients other than `tkScrim`, Canvas, `Text` concatenation (`Text.foregroundColor(palette...)` — sugar can't keep the `Text` type), or a platform API that explicitly requires `Color`.
- **Previews**: `#Preview` roots get `.tkPreviewTheme(_:)`; sample data keeps `TKColor`, or uses an explicit `TKResolvedTheme.<theme>.palette` only when a raw color is unavoidable. `TKPreview.palette` follows the singleton and is legacy-only. See [SwiftUI Previews](#swiftui-previews) for where previews are allowed to live.
- **Hosting**: all SwiftUI hosting goes through `TKHostingController` (swiftlint-enforced) — it installs the theme environment.
- **New tokens**: colorsets under `TKUIKitResources` `Assets.xcassets/Colors/<Category>/<Name>/<Theme>.colorset` for all three themes, then `make resources`. Token statics stay category-prefixed (`accentBlue`, not `blue`) — a bare SwiftUI-vocabulary name (`clear`, `red`, `primary`, …) would collide with native modifier overloads; guarded by `testColorTokenNamesStayOutOfSwiftUIStyleVocabulary`.
- `Color(uiColor: .Text.primary)`-style snapshots are non-reactive and swiftlint-flagged (`no_static_palette_color_in_swiftui`). Do not try to extend the regex lint into data-flow analysis: it cannot reliably distinguish a safe dynamic `UIColor` from a snapshot. Prefer the typed APIs and tests instead.
- `TKColor.clear` is the intentional exception to the token naming rule: it is semantically identical to SwiftUI's `.clear` and is needed where typed `TKColor` branches must remain uniform.

## SwiftUI Previews
Native `#Preview` (Xcode canvas / Xcode MCP `RenderPreview`) is the UI feedback loop: edit → PNG without running the app. In the currently verified Xcode setup, preview JIT fails when a target graph reaches the static binary archives `libsodium.a` or `libyttrium.a`, so previewable targets must stay outside the crypto graph.

**Where SwiftUI views go**
- keep an existing feature cluster in its appropriate crypto-free owner; otherwise reusable component → `TKUIKit`, product screen → `AppUI` (`LocalPackages/AppModules/AppUI`, depends on `TKUIKit`/`TKLocalize` — extend with crypto-free deps as needed);
- in the current dependency graph, views in `App`, `TonkeeperWidget`, or a `KeeperCore`/`TKCore` dependent are not compatible with `RenderPreview` because they reach the crypto archives;
- splitting a screen: view + flat view-state model in `AppUI`, while the view model / mapper / coordinator that touches `KeeperCore` stays in `App` and passes the flat model in. Types consumed from `App` need explicit `public` + `public init`. Move a screen as a cluster (root view + subviews + flat model) — a per-view border costs more `public` than it buys — and only when the screen is actually being reworked.

**Images and text across the preview boundary**

- bundled design assets use the generated `SwiftUI.Image.TKUIKit`/`UIImage.TKUIKit` API. Reuse an existing asset first; otherwise create a matching `<name>.imageset` under `LocalPackages/TKUIKitResources/Sources/TKUIKitResources/Resources/Assets.xcassets`, follow a neighboring `Contents.json`, and run `make resources`. New vector assets are PDF-only: never import SVG; existing legacy SVGs are not precedent. A Figma `localhost` URL is only a download source, never a production runtime URL;
- remote/runtime images cross into a previewable module as `URL?` or an existing `TKUIKit` image-source type; loading/rendering stays in `TKUIKit`, and previews use deterministic bundled or in-memory images instead of the network. Do not add `Kingfisher` directly to `AppUI`;
- user-facing text uses `TKLocales`; for a new key follow [Localization Workflow](#localization-workflow) via `locale-sync`, which regenerates accessors when the key set changes.

**Preview file** — put new previews in a sibling `<View>+Previews.swift`, not inside the view file. Design-time instrumentation then rewrites only the preview file, which rebuilds faster and avoids the reproduced `ambiguous use of '__designTimeSelection'` failure.
```swift
import SwiftUI
import TKUIKit

#Preview("Deep Blue") {
    SomeView(state: .preview)
        .tkPreviewTheme(.deepBlue)
}
```
- **`#Preview` only** — do not add new `PreviewProvider`; it is legacy and is not part of the verified MCP preview flow.
- **`.tkPreviewTheme(.light / .dark / .deepBlue)`** pins palette + `TKThemeManager` + `colorScheme` in one step, so SwiftUI content and UIKit controls agree and the PNG does not depend on the theme saved on the machine. Preview theme pinning is non-persistent and never overwrites the theme selected in the app. `.tkThemed()` follows `TKThemeManager.shared` and `RenderPreview`'s `Color Scheme` variant does not repaint the palette — neither is reproducible.
- **Mocks are self-contained**: no DI, network, keychain. A protocol-driven view gets a small `private final class …PreviewViewModel` in the preview file; sample data lives on the flat view state (`static let preview`) so a preview stays three lines.
- **Screens keep device geometry**: use a separate named `#Preview` for each full-screen state or Figma frame. Match the Figma frame to the corresponding simulator/device geometry; do not replace device safe areas with `.fixedLayout`. Do not stack screens into one tall gallery.
- **Component states share one compact gallery** when they are meant to be compared together. The project targets iOS 15, so preview traits need a local availability annotation; give compact renders an explicit background because they have no device backdrop:
  ```swift
  @available(iOS 17.0, *)
  #Preview("States", traits: .sizeThatFitsLayout) {
      VStack(spacing: 16) {
          SomeView(state: .previewDefault)
          SomeView(state: .previewSelected)
      }
      .padding()
      .background(.backgroundPage)
      .tkPreviewTheme(.deepBlue)
  }
  ```
  Use `.fixedLayout(width:height:)` when a component has an exact frame to reproduce.
- **UIKit components can use native `#Preview` inside `TKUIKit`**. Prefix it with `@available(iOS 17.0, *)`, build the view in an `@MainActor` factory, call `TKPreview.pinTheme(_:)` before resolving UIKit color tokens, and use `.fixedLayout(width:height:)` for a compact MCP snapshot (`.sizeThatFitsLayout` still rendered on the device canvas in the verified UIKit case). Keep this internal; SwiftUI product screens still belong in `AppUI`.

**Visual validation** — when Xcode MCP is available, render the sibling preview and inspect the returned PNG. The Figma-specific comparison loop lives in `.agents/skills/figma-implement-design`. Preview rendering does not validate Dynamic Type because `TKTextStyle` fonts are fixed-size.

**Troubleshooting**
- `JITError: Runtime linking failure`, or `Preview not available` near a preview declaration → the target reaches the crypto graph: a dependency leaked into the previewable target, or the view still lives in `App`.
- `ambiguous use of '__designTimeSelection'` → a common cause is a `#Preview` co-located with the view; move it to the sibling file.
- palette does not match the design → use `.tkPreviewTheme(_:)`.
- `file '…/ChainKit.h' has been modified since the module file … was built` → in the verified Xcode 26.3 case, GUI DerivedData carried stale explicit modules after a package-manifest change. Delete `<GUI DerivedData>/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules` and render again. This is unrelated to `make compile`, which uses its own in-repo DerivedData.
- `Conflicting options '-warnings-as-errors' and '-suppress-warnings'` → this was reproduced for `AppUI`, whose manifest therefore uses the frontend `-warnings-as-errors` flag. `TKUIKit` retains `.treatAllWarnings(as: .error)` and previews successfully in the verified setup, so do not generalize the cause or copy the workaround to another package without reproducing the conflict there.

**Scaling** — `AppUI` is for shared product views; a large feature cluster gets its own `<Feature>UI` target once previews or the isolated type-check get slow. Add a shared scheme under `Tonkeeper.xcodeproj/xcshareddata/xcschemes/` that contains the new preview target; `RenderPreview` cannot select a target without an available scheme. Previewable targets never depend on `KeeperCore`, `TKCore`, `TronSwift`, `Ledger`. Apply these rules to new or touched previews; migrate legacy previews opportunistically, not as a mechanical sweep. No CI check for previewability: after an Xcode upgrade or a SwiftPM graph change, manually re-render a stable preview in the affected target.

**Headless / CI** — the verified preview workflow is GUI-bound and has no baseline-image suite; use the manual preview validation above.

## Skills Usage
- **Task context**: `.agents/skills/linear/SKILL.md` fetches task details. Task id inferred from the branch name (`author/task_id/description`, per `scripts/hooks/commit-msg`). Needs corporate VPN; if fetch fails, suspect VPN.
- **Committing**: the task id is auto-appended by `scripts/hooks/commit-msg` — do not add it manually. The hooks are installed in the repository's common Git directory by `make hooks` (part of `make setup`); rerun `make hooks` if the id stops being appended.
- **TON domain**: `.agents/skills/tondocs/SKILL.md`.
- **PR data**: `.agents/skills/pr/SKILL.md` imports GitHub PR metadata + diffs as LLM-friendly Markdown.
- **Release QA impact**: `.agents/skills/tk-impact-analysis/SKILL.md` maps the branch-vs-release diff to regression test blocks (platform `regress_EN.txt`).
- **Skill readiness**: run the skill's dependency/env check (per its README) first; if it fails, explain and continue without the skill.

## MCP Servers
- Declared per agent in `.mcp.json` (Claude Code), `.cursor/mcp.json` (Cursor), `.codex/config.toml` (Codex). Keep the server set in sync across all three.
- Servers:
  - **figma** (remote, OAuth) — design context; used by `.agents/skills/figma-implement-design`.
  - **linear** (remote, OAuth) — task context; used by `.agents/skills/linear`. Needs corporate VPN.
  - **xcode** (`xcrun mcpbridge`, Xcode 26.3+ with MCP enabled in Settings → Intelligence) — builds, tests, simulator control, SwiftUI previews, build logs.
- Remote servers (figma, linear) need a one-time per-user OAuth login (Step 0 of the skill).
- Server unavailable (not installed / not logged in) → explain and continue; `make` is the build/test fallback.

### Opportunistic Xcode MCP tools (only when the xcode MCP server is connected)
**GUI-bound**: every tool needs a `tabIdentifier` from a running Xcode window. Target this worktree by opening its project once — `xed Tonkeeper.xcodeproj` from the worktree root adds a tab to the same Xcode process; `XcodeListWindows` returns its `tabIdentifier`. GUI builds need `make firebase_config`. These tools ignore the tuned build env (private-SPM creds, Crashlytics build phase, per-worktree DerivedData), so `make` stays default for builds/tests/CI — use them only for fast spot-checks.
- **`RenderPreview`** — SwiftUI preview snapshot. The target's entire dependency graph must stay free of the crypto/DI graph; otherwise JIT fails on static libsodium symbols. `sourceFilePath` is a project-organization path (`AppUI/Sources/AppUI/…`), not a filesystem path — resolve it with `XcodeGlob`.
- **`ExecuteSnippet`** (Xcode 26.x; `RunCodeSnippet` on 27+) — run a Swift snippet in a file's context, spot-check logic via `print`. It has the same crypto-free dependency-graph constraint as `RenderPreview`.
- **`GetBuildLog`** (`severity`/`pattern`/`glob` filters) — pull only errors from a GUI build.

## Localization Workflow
- Devs edit keys manually only in `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings`.
- Agents generate the other `*.lproj/Localizable.strings` from the English source.
- Never hand-edit `LocalPackages/TKLocalize/Sources/TKLocalize/TKLocales.swift`; regenerate only via `make locale` from repo root.
- The `.agents/skills/locale-sync` skill packages this flow (sync targets from English + regenerate accessors).

## Analytics Workflow
- Generate only via `make analytics` from repo root → runs `scripts/analytics/sync_models.sh`, which updates the schemas checkout at `.context/analytics-schemas` (override with `ANALYTICS_SCHEMAS_ROOT`).
- Whitelist: `scripts/analytics/event_model_whitelist.txt` (auto-sorted each run).
- Whitelisted + still in schema → copied to `LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Generated`.
- Whitelisted + removed from schema → preserved as backports in `.../Events/Deprecated` (first run moves the generated file there; later runs keep it until removed from the whitelist).
- Not in whitelist → deleted from both `Generated` and `Deprecated`.

### Ingestion limits
Both backends silently discard what they cannot accept, so a violation shows up as missing data, not as an error:
- **Aptabase** (`anonymous-analytics.tonkeeper.com`, server-side `EventBody.IsValid`) — property key non-blank and ≤ 40 chars, event name ≤ 60, session id numeric or ≤ 36 chars, event no older than 24h (the store's TTL is 23h) and no more than 10 min in the future, ≤ 25 events per batch. String values are truncated to 180 server-side; non-scalars are coerced. A bad property key is a **400 for the whole payload** on `/api/v0/event` (the SDK transport), so one long key loses every other property of that event, system props included; `/api/v0/events` (the queued transport) drops just that event. A 4xx on the batch path condemns the whole request instead (model validation, account-level errors), so `AptabaseQueueClient` resends such a batch one event at a time and loses only what the server actually refuses; `.networkAvailable` clears the retry backoff so a reconnect does not wait it out.
- **Firebase/GA4** — event name ≤ 40 chars, parameter name ≤ 40, parameter string value ≤ 100, ≤ 25 parameters per event, names `[A-Za-z][A-Za-z0-9_]*` with no `firebase_`/`google_`/`ga_` prefix. Only the five name-only `logFirebase` events and `tc_return_strategy_seen` go there today — `FirebaseAnalyticsService` is not in `CoreAssembly`'s `analyticsServices`. Routing schema events to Firebase would newly bind the 40-char event-name and 25-parameter limits (`launch_app` with the `ff_*` flags is already over 25).

Three gates keep a key inside those limits, since the failure is invisible at the call site:
- `AnalyticsLimits.sanitizeKeys` in `AnalyticsProvider` — the runtime net: blank keys dropped, over-long keys truncated to 40 (deterministic on collision) so the rest of the event survives, plus an `assertionFailure` in DEBUG.
- `make analytics_check` (also run by `make analytics`) → `scripts/analytics/check_key_limits.py` — the gate for generated models, which `.swiftlint.yml` excludes.
- `no_over_long_analytics_key` swiftlint rule + `AnalyticsLimitsTests` (covers every `FeatureFlag` `ff_*` key and `EventKey` name) for hand-written keys.

## OpenAPI Clients
- The API targets under `LocalPackages/KeeperCore/Packages/` (`SwapAPI`, `MultichainAPI`, `TonConnectAPI`, `TKTonkeeperAPI`, `TKTradingAPI`, `TKPerpsAPI`, `TKKandelabrAPI`) are emitted by `swift-openapi-generator` — never hand-edit their sources.
- Edit the schema at `scripts/apigen/schemas/<name>.yml`, then regenerate with the matching target: `make swap_generate`, `make multichain_generate`, `make tonconnect_generate`, `make tonkeeper_generate`, `make trading_generate`, `make perps_generate`, `make kandelabr_generate`. `make api_generate` does all of them; `make api_check` regenerates into a temp dir and fails if a checked-in client no longer matches its schema.
- They all share one generator package (`scripts/apigen`) with an exact `swift-openapi-generator` pin in its committed `Package.resolved` — the generated sources are checked in, so a floating generator version made the output depend on who ran it. A new API is one row in the `APIS` table of `scripts/apigen/generate.sh` plus its schema file.

## Maestro UI Tests
- `maestro_ui_tests/README.md` is the map (flows, steps, sharding, CI wiring); the suite runs via `.github/workflows/maestro-ui-tests.yml`.
- Maestro has no JS import mechanism, so `maestro_ui_tests/scripts/api/_api_runtime.js` is stamped into every consumer script between `// >>> api-runtime` markers. After editing the runtime run `make maestro_api_sync`; CI fails the job on an unsynced copy (same script with `--check`, i.e. `make maestro_api_check`).

## Path Safety
- **No hardcoded absolute paths** in scripts/source; prefer repo-relative paths, env overrides, or lazy clones for remote repos.

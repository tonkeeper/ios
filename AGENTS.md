# Repository Guidelines

## Repository Layout
- Paths are relative to `ios/`; ones starting with `shared/`, `.github/`, `.githooks/`, `.claude/`, `.agents/`, `.codex/`, `.cursor/`, `.context/` or `.env` are repository-root paths.
- `ci_scripts/` must stay next to the Xcode project: Xcode Cloud runs custom scripts only from there, and a misplaced one fails the archive much later, at the `Firebase plist` phase.
- The public mirror (`.github/workflows/mirror-public-push.yml`) publishes `ios/` as the root of `tonkeeper/ios`, with `../shared/{api,resources,tools}` as `api/`, `resources/`, `tools/`.

## Project Structure
- `Keeper/` — main app source and resources.
- `KeeperWidget/`, `KeeperIntents/`, `KeeperNotificationService/` — extension targets.
- `LocalPackages/` — SwiftPM modules:
  - **Domain/infra**: `KeeperCore` (wallet domain: API, controllers, entities), `TKCore` (analytics, Firebase, push, formatters; services live in its `TKServices` target, which must not depend on `KeeperCore`), `TronSwift` (Tron; hosts `TKCryptoKit` tests), `Ledger` (hardware-wallet transport).
  - **Perps**: `PerpsModels` — Foundation-only domain models and store/service ports, shared by `KeeperCore` and `App`; `AppModules/Perps` — the perps feature.
  - **Operation review**: `OperationReviewModels` — Foundation-only findings of a review of what is about to be signed, and the user's consent to them, for `KeeperCore` and crypto-free UI.
  - **UI**: `TKUIKit` (resources in `../shared/resources`), `TKCoordinator`, `TKScreenKit`, `LightweightCharts` (vendored TradingView fork).
  - **Support**: `TKLocalize` (generated, see [Localization](#localization)), `TKKeychain`, `TKLogging`, `TKFeatureFlags`, `TKAppInfo`. They, `PerpsModels`, `OperationReviewModels` and vendored `AnyCodable` build as one package, `TKBase`: its `Sources/` link to each module's own folder, so `make spm PKG=TKBase` checks them all.
  - `App/` — top-level assembly and coordinators. `AppModules/<Pkg>` — App-only feature packages: `AppUI` (crypto-free product views, see [SwiftUI Previews](#swiftui-previews)), `Perps`, `Stories`, `SignRaw`, `WalletExtensions`, `MoonPay` (depends only on `TKBase`).
- `Configurations/` — `.xcconfig` build settings. `Keeper.xcodeproj/` — the Xcode project.

## Build and Test
1. Edited `LocalPackages/<X>` → `make spm PKG=X` (Swift-only type-check; bare package name, also for `AppModules/*` and `KeeperResources`; `QUIET=1` prints only a failed build's diagnostics).
2. Edited `App/` or several packages → `make spm PKG=App` or `make spm PKG="TKUIKit TKCore"`. The first run compiles the whole dependency tree.
3. Before declaring done → `make compile QUIET=1`: catches build-phase, linker and signing issues `make spm` misses; pass/fail is the exit code. Drop `QUIET=1` only to diagnose.
4. Changed tested logic → the relevant `make test_* QUIET=1`: only errors, failed tests and test counts.

Tests run only through `make`, which uses the app-level `Package.resolved`; never `swift test` or `xcodebuild` inside `LocalPackages`.
```sh
make test_all   # every unit-test bundle; alias: make test
make test_keeper_core   # per module: test_tkcore, test_wallet_core, test_core_components, test_tklocalize,
                        # test_tkuikit, test_perps, test_moonpay, test_ledger, test_tron_swift, test_tkcryptokit
make test_project_scheme SCHEME=WalletCore TEST_ONLY=KeeperCoreTests/TonkeeperDeeplinksParserTests/testActionParsing
```
A new test target goes into `KeeperUnitTests.xcscheme` (`make test_all` and the GitHub unit-test job, `.github/actions/run-unit-tests`) and `KeeperCI.xctestplan` (run by `ci_scripts/ci_post_xcodebuild.sh` after the Xcode Cloud pull-request workflow's Build action of `KeeperCIGate`); a target missing from either is silently not run there.

## Worktrees
- Do refactors and features in a worktree under `.claude/worktrees/<name>` (where `EnterWorktree` puts them): `git worktree add .claude/worktrees/<name> -b <branch>`.
- Each worktree holds its own `ios/build/` (17–33 GB). Remove it once its branch is merged — judge by `git merge-base --is-ancestor <sha> origin/dev`, not the branch name; skip dirty or locked ones:
  ```sh
  git worktree remove .claude/worktrees/<name> && rm -rf .claude/worktrees/<name>
  git worktree prune
  ```
  `git worktree remove` leaves the gitignored `ios/build/` behind, so sweep the directory listing, not only `git worktree list`.
- Firebase config (`Keeper/Resources/Firebase`) is gitignored; `make compile` and the `post-checkout` hook copy it from the main tree. Manually: `make firebase_config`.
- `make` seeds SwiftPM dependencies from an already-resolved store (`scripts/provision_spm_deps.sh`); re-seed by deleting the store's `workspace-state.json`. `make xcode_derived_data` moves Xcode GUI DerivedData into `build/DerivedData-xcode`.

## Linking
Each launch loads every embedded framework, so the app embeds only `KeeperCore` (the wallet stack), `TKUIKit` (UI) and `TKBase` (modules both use), plus the binary SDKs.
- A package product that one of these three links is owned by it. Other targets (`App`, `AppModules/*`, extensions, `TKCore`) import its modules and do not declare it: a second declaring target makes Xcode embed the product as its own `*_PackageProduct.framework`.
- A new module that both `KeeperCore` and `TKUIKit` need goes into the `TKBase` product.
- `make compile` fails on any other embedded framework (`scripts/check_embedded_frameworks.sh`).

## Package Build Settings
- `Configurations/PackageBuildSettings.xcconfig` holds settings for SwiftPM targets (a project xcconfig never reaches them), applied via `XCODE_XCCONFIG_FILE` by `make` and Xcode Cloud, not by Xcode GUI.
- It builds `KeeperCore` with library evolution, so every `KeeperCore` public enum must be `@frozen` (swiftlint `frozen_keeper_core_public_enum`; an enum made public by a `public extension` is caught only by the build).

## Code Style
- `make format` runs `swiftformat`; committed code is already formatted.
- Tool versions are pinned in `mise.toml` (`make setup` installs them); call tools through `scripts/tools/tool.sh`. If a newer swiftformat rule rewrites untouched files, add `--disable <rule>` to `.swiftformat` instead of reformatting the repo.
- **Comments**: Do not add comments without clear necessity. Code should read for itself; names and types carry intent. Write a comment only to explain a non-obvious *why* (a subtle invariant, a workaround, a deliberate deviation) or as a short doc for a public API. Do not narrate *what* the code does, restate the method name, or leave porting/implementation-history notes.

## Concurrency
- Prefer Swift concurrency primitives over GCD, locks and completion handlers: `async`/`await` APIs, an `actor` for shared mutable state, `@MainActor` for UI-owned state and view models. Do not use the main queue or `@Atomic` to synchronize new code; `@Atomic` guards a single access, not an invariant.
- Types crossing isolation boundaries are `Sendable`: value types or immutable `final` classes. `@unchecked Sendable` only for a type whose state is fully guarded internally, with a one-line *why*. `nonisolated(unsafe)` and `@preconcurrency import` are for boundaries with unannotated third-party code, never to silence a diagnostic.
- Structured concurrency first: `async let`, `withTaskGroup`/`withThrowingTaskGroup`, SwiftUI `.task {}`. An unstructured `Task {}` only at a sync→async boundary — keep its handle if it must be cancelled. Avoid `Task.detached`.
- Bridge callback APIs with `withChecked(Throwing)Continuation`, resumed exactly once on every path, including cancellation and teardown; a continuation stored beyond its scope has one owner. Expose event streams as `AsyncStream` with cleanup in `onTermination` instead of hand-rolled observer lists.
- Actors are reentrant: state can change across any `await`. Re-check invariants after suspension and never split check-then-act around an `await`.
- Perform cancel-and-replace inside one isolation domain. Cancellation is cooperative: check `Task.isCancelled` / `Task.checkCancellation()` and verify that a result still belongs to the current operation or scope before applying it.
- When changing shared mutable state, add focused deterministic tests for non-obvious cases: reentrancy, overlapping operations, cancellation, stale completion. Use TSan selectively when correctness depends on real thread interleaving.
- Tests wait for events, not for time. Use `waitUntil`, `TestSignal` and `TestGate` from the `TKTestSupport` product of `TKBase`. Make a delay in the code under test a parameter with the production default. swiftlint `no_time_based_wait_in_tests` warns on a sleep or a timed wait in a new test file.

## State invalidation
For derived, cached, or asynchronously loaded state:
- Identify the inputs and lifecycle transitions that affect it. Invalidate it whenever an input changes; refresh eagerly only when required by product behavior. Reset related one-shot and lifecycle guards on the same transitions.
- Include every relevant input in the cache key or scope so a changed scope cannot return stale data.
- On scope changes, cancel obsolete work when useful and prevent obsolete completions from updating the new scope.
- Derive list-item identity from stable domain data, never a fresh `UUID()` per render.

## Colors & Theming (SwiftUI)
Palette colors must react to theme switches (light/dark/deepBlue) at render time. Rules, in order of preference:
- **Default**: themed modifier overloads with `TKColor` tokens — `.foregroundStyle(.textPrimary)`, `.background(.backgroundPage)`, `.fill(.accentBlue)`, `.stroke(.separatorCommon)`, `.strokeBorder(.fieldActiveBorder)`, `.shadow(color: .backgroundOverlayLight, radius: 8)`, `.tint(.accentBlue)`. `TKColor` is also a `View` for backgrounds, separators and overlays. No `@Environment` needed.
- **Configs / view models**: store `TKColor` (or `TKThemedText` for attributed spans), never `Color`/`UIColor`/`AttributedString` with baked palette colors; the rendering view resolves via `.resolve(palette)`.
- **Per-scheme divergence outside the palette**: `TKColor.perTheme(light:dark:deepBlue:)`; for whole-view branching read `@Environment(\.tkResolvedTheme)`.
- **Scrims**: `.tkScrim(.backgroundPage, edge: .bottom)` for the standard page fade.
- **`@Environment(\.tkPalette)`** only where a raw `Color` is genuinely needed: other gradients, Canvas, `Text` concatenation, or a platform API that requires `Color`.
- **Previews**: `#Preview` roots get `.tkPreviewTheme(_:)`; sample data keeps `TKColor`. `TKPreview.palette` is legacy-only.
- **Hosting**: all SwiftUI hosting goes through `TKHostingController` (swiftlint-enforced) — it installs the theme environment.
- **New tokens**: colorsets under `KeeperResources` `Assets.xcassets/Colors/<Category>/<Name>/<Theme>.colorset` for all three themes, then `make resources`. Token names stay category-prefixed (`accentBlue`, not `blue`) to avoid colliding with SwiftUI's own names; `TKColor.clear` is the one exception.
- `Color(uiColor: .Text.primary)`-style snapshots are non-reactive (swiftlint `no_static_palette_color_in_swiftui`). Don't extend that regex lint into data-flow analysis; prefer typed APIs and tests.

## SwiftUI Previews
Native `#Preview` (Xcode canvas / MCP `RenderPreview`) is the UI feedback loop. Preview JIT fails when a target reaches the static archives `libsodium.a` or `libyttrium.a`, so previewable targets never depend on `KeeperCore`, `TKCore`, `TronSwift` or `Ledger`.

**Where views go**
- Keep an existing feature cluster in its crypto-free owner (perps → `AppModules/Perps`); otherwise reusable component → `TKUIKit`, product screen → `AppUI`.
- Views in `App`, `KeeperWidget` or a `KeeperCore`/`TKCore` dependent cannot be previewed.
- Splitting a screen: the view and a flat view-state model go to the previewable package (`public` + `public init`); the view model, mapper and coordinator touching `KeeperCore` stay in `App`. Move a screen as a cluster, and only when reworking it. When view models depend only on ports, move them too — in `AppModules/Perps` each view is generic over a `@MainActor public protocol <Screen>ViewModeling: ObservableObject`, and the preview supplies a `private final class …PreviewViewModel`.

**Images and text**
- Bundled assets use the generated `Image.TKUIKit`/`UIImage.TKUIKit` API. Reuse an existing asset first; a new one is an `<name>.imageset` under `../shared/resources/Sources/KeeperResources/Resources/Assets.xcassets`, then `make resources` (rasters shared with Android: `../shared/resources/README.md`). New vectors are PDF only, never SVG. A Figma `localhost` URL is a download source, never a runtime URL.
- Remote images cross the boundary as `URL?` or a `TKUIKit` image-source type and render with `TKRemoteImage`, never `KFImage` (swiftlint `prefer_tk_remote_image`). Previews use bundled or in-memory images.
- User-facing text uses `TKLocales`; add keys via [Localization](#localization).

**Preview file** — new previews go in a sibling `<View>+Previews.swift`, not the view file (faster rebuilds, avoids `ambiguous use of '__designTimeSelection'`).
```swift
import SwiftUI
import TKUIKit

#Preview("Deep Blue") {
    SomeView(state: .preview)
        .tkPreviewTheme(.deepBlue)
}
```
- `#Preview` only; no new `PreviewProvider`.
- `.tkPreviewTheme(.light / .dark / .deepBlue)` pins the theme for SwiftUI and UIKit without touching the app's saved theme. `.tkThemed()` and `RenderPreview`'s Color Scheme variant are not reproducible.
- Mocks are self-contained (no DI, network, keychain); sample data lives on the flat view state (`static let preview`).
- Full screens: one named `#Preview` per state or Figma frame, with device geometry; no tall galleries.
- Component states share one compact gallery; the project targets iOS 15, so traits need an availability annotation:
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
  Use `.fixedLayout(width:height:)` for an exact frame.
- UIKit components in `TKUIKit` can use `#Preview` too: `@available(iOS 17.0, *)`, an `@MainActor` factory, `TKPreview.pinTheme(_:)` before resolving color tokens, `.fixedLayout(width:height:)`.
- Rendering does not validate Dynamic Type (`TKTextStyle` fonts are fixed-size). Figma comparison lives in the `figma-implement-design` skill.
- A large feature cluster gets its own `<Feature>UI` target plus a shared scheme in `Keeper.xcodeproj/xcshareddata/xcschemes/` (`RenderPreview` needs one).

**Troubleshooting**
- `JITError: Runtime linking failure` / `Preview not available` → the target reaches the crypto graph.
- `XCPreviewAgent crashed because <X>.framework is missing` → `TKUIKit` (a dynamic framework) gained an explicitly `.dynamic` dependency; keep its dependencies automatic products (see `LocalPackages/TKUIKit/Package.swift`).
- `ambiguous use of '__designTimeSelection'` → move the `#Preview` to the sibling file.
- `file '…/ChainKit.h' has been modified since the module file … was built` → delete `<GUI DerivedData>/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules`.
- `Conflicting options '-warnings-as-errors' and '-suppress-warnings'` → reproduced only for `AppUI`; don't copy its manifest workaround elsewhere without reproducing.

## Skills and MCP
- Linear (skill and MCP server) needs corporate VPN; on a fetch failure suspect VPN. The task id comes from the branch name (`author/task_id/description`).
- `.githooks/commit-msg` prefixes the task id to the commit subject — do not add it manually; if it stops, rerun `make hooks`.
- Run a skill's dependency check (per its README) first; if it fails, explain and continue without the skill. An unavailable MCP server likewise: `make` is the build/test fallback.
- The xcode MCP server needs Xcode 26.3+ with MCP enabled in Settings → Intelligence. Remote servers (figma, linear) need a one-time OAuth login.

### Xcode MCP tools (only for spot-checks)
- GUI-bound: open this worktree's project with `xed ios/Keeper.xcodeproj` and take its `workspaceIdentifier` from `XcodeListWorkspaces` (`tabIdentifier` from `XcodeListWindows` before Xcode 27). GUI builds need `make firebase_config` and ignore the `make` build env, so `make` stays the default.
- `RenderPreview` — preview snapshot; `sourceFilePath` is a project path (`AppUI/Sources/AppUI/…`), resolve it with `XcodeGlob`.
- `ExecuteSnippet` (`RunCodeSnippet` on Xcode 27+) — run a Swift snippet in a file's context; same crypto-free constraint as `RenderPreview`.
- `GetBuildLog` with `severity`/`pattern` filters — errors only.

## Localization
- Devs edit keys manually only in `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings`, and in `ru.lproj` when the design gives the Russian.
- The other locales come from the `Translations` workflow (`../.github/workflows/android-locales-translate.yml`): the nightly run on dev translates new and changed keys into a PR, except, once `XCODE_CLOUD_RELEASE_WORKFLOW_ID` is set, keys with the same English as the latest release branch that has `iOS Publish`: it translates them there and they come back with the back-merge. It never overwrites a Russian written by hand, unless its placeholders no longer match the English.
- Every string goes through `String(format:)`: a percent sign is `%%`, even with no placeholder.
- Never hand-edit `LocalPackages/TKLocalize/Sources/TKLocalize/TKLocales.swift`; regenerate only via `make locale`.
- The `locale-sync` skill packages this flow.

## Analytics
- Generate only via `make analytics` (schemas checkout at `.context/analytics-schemas`, override with `ANALYTICS_SCHEMAS_ROOT`).
- `scripts/analytics/event_model_whitelist.txt` controls output: whitelisted and in schema → `TKServices/Analytics/Events/Generated`; whitelisted but removed from schema → kept in `Events/Deprecated`; not whitelisted → deleted.
- Backends silently drop what they can't accept: keep property keys ≤ 40 chars (Aptabase drops the whole event otherwise) and event names ≤ 60 (≤ 40 if routed to Firebase). Guards: `AnalyticsLimits.sanitizeKeys` at runtime, `make analytics_check` for generated models, swiftlint `no_over_long_analytics_key` and `AnalyticsLimitsTests` for hand-written keys.

## App Store Release
- `make appstore_toolings [ACTION=info|release|status] [VERSION=YY.MM.N] [DRY_RUN=1]`; credentials `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_PATH` in the root `.env`. Release notes come from `scripts/appstore/whats_new.txt`.
- `info` on a released or in-review version offers the next one (an editable version if any, else the `scripts/bump_version.sh` rule) and creates it; `VERSION=` picks another. It then attaches the build (`BUILD=<number>`), sets the release type (`RELEASE=manual|auto`) and the phased 7-day rollout (`PHASED=on|off`), and pushes What's New. `release` does the one step the version's state allows: submit to review, publish an approved manual version, or pause / resume / complete a running phased rollout (`ROLLOUT=pause|resume|complete`). Publishing also tags the tip of `release/ios/<ver>` as `ios/<ver>_<build>` and pushes the tag to origin; a tip committed after the build's upload is refused, `COMMIT=<sha>` names the built commit instead.
- `status` posts the version's state to Slack (`waiting for review`, `1%` … `100%` by phased day); needs `SLACK_BOT_TOKEN` and `SLACK_RELEASES_CHANNEL` in the root `.env`. The `.env` loader and the Slack poster are `../shared/scripts/release_slack.py`, shared with Android's `playstore_toolings`; the public mirror has no `shared/scripts/`, so there `status` is unavailable and the other actions read the credentials from the environment only.
- Build a release with the `iOS Publish` GitHub workflow (`../.github/workflows/ios-publish.yml`) on `release/ios/<YY.MM.N>`: it checks that `APP_VERSION_COMMON` in `Configurations/common.xcconfig` is the branch's version, that no PR into the branch is open and that every key is translated, then starts the Xcode Cloud Release workflow (`XCODE_CLOUD_RELEASE_WORKFLOW_ID`) through the API. That workflow starts only by hand: set the variable after its start on push is removed. For untranslated keys it starts `Translations` on the branch and fails: merge that PR, then run it again. `skip_inspections` drops the checks; the version still has to be `YY.MM.N`. Branches cut before it have no `iOS Publish`: translate them with `Translations` (branches cut after TK-6566) or the `locale-sync` skill, and start the build in Xcode Cloud.
- It prompts before creating, declaring, submitting, releasing, changing a rollout or posting; without a terminal pass `CREATE=1`, `ENCRYPTION_EXEMPT=1` or `YES=1` (release options stay as they are unless `RELEASE`/`PHASED` are given).

## OpenAPI Clients
- Python schema preparation requires PyYAML, pinned in `scripts/apigen/requirements.txt`. Local `make setup` installs it into `build/apigen-python`, which generation uses automatically; CI may provide it through its active `python3`. For generation without the full setup (including the public mirror), run from the iOS root:
  ```sh
  python3 -m venv build/apigen-python
  build/apigen-python/bin/python3 -m pip install -r scripts/apigen/requirements.txt
  ```
- REST clients are generated by `swift-openapi-generator` into `LocalPackages/KeeperCore/Packages/`; never hand-edit them. Add a client through the `APIS` table in `scripts/apigen/generate.sh`.
- Local schemas: `scripts/apigen/schemas/<name>.yml`; generator settings: `scripts/apigen/configs/<name>.yaml`. After a local schema edit run `make <api>_generate`; `make api_generate` regenerates all, `make api_check` detects stale sources.
- `OPEN_ENUM_APIS` clients decode unknown string enum values as `.unknown`; handle that case at call sites.
- `NULLABLE_ANY_OF_APIS` specs (OpenAPI 3.1 `anyOf: [<scalar>, null]`, which the generator skips) go through `scripts/apigen/nullable_any_of.py` before generation; the stored schema stays as published.
- Shared clients use `shared/api/filters/<api>.yaml` as the operation/model allowlist for both platforms; `configs/<api>.yaml` keeps Swift-specific settings. Local-only clients keep their filters in `configs/<api>.yaml` (TonConnect has no config: both operations are used). Before calling a new operation, add it to `filter.operations` and run `make <api>_generate`; a response type needed outside those operations goes under `filter.schemas`. `TonStreamingAPIV2`, `EventSource` and `StreamURLSessionTransport` are vendored and not regenerated.

## Path Safety
- No hardcoded absolute paths in scripts or source. Scripts derive the project root as `<git toplevel>/ios` or from `$0`. GitHub Actions prefix paths with `ios/` explicitly: a job-level `working-directory` does not reach composite actions.

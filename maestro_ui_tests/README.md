# Maestro UI tests

iOS UI tests run with [Maestro](https://maestro.mobile.dev) against the Tonkeeper
app on the iOS Simulator — one multichain-enabled build, sharded by section and
orchestrated by `.github/workflows/maestro-ui-tests.yml`.

This README is the fast-context map: **where things live, how the pipeline is
wired, and where to change X**. Update it as the setup evolves.

---

## TL;DR — where do I change …?

| I want to… | Go to |
| --- | --- |
| Rename the native token ticker (TON → GRAM …) | `ci/native_token_env.sh` (`NATIVE_TOKEN_DISPLAY_TEXT`, `NATIVE_TOKEN_SHORT_TEXT`) |
| Add/adjust a test flow | `flows/multichain/<section>/<name>.yaml` |
| Add a new shard (section) | create `flows/multichain/<section>/`, add `flows/multichain/<section>/*` to `config.yaml`; a TON-seed section is named `ton_<section>` and listed in `ton_wallet_shards` |
| Change the build's feature flags / artifact | `config.yaml` + `ci/multichain-flags.json` |
| Share steps between flows | `steps/**` (referenced via relative `runFlow`) |
| Change the shared HTTP helper for API scripts | `scripts/api/_api_runtime.js`, then `make -C ios maestro_api_sync` |
| Add an API assertion (query TonAPI, compare on-chain state) | `scripts/api/**` + a `service/**` subflow |
| Skip a flaky/broken flow but keep it green | wrap its body in `runFlow: { when: { true: "${false}" } }` |
| Run the suite's build locally | `ios/Keeper/Resources/FlagsOverride.json`, seeded from `ios/maestro_ui_tests/ci/multichain-flags.json`. CI merges that file onto the secret `MAESTRO_FEATURE_FLAG_OVERRIDES` |
| Explore the app / write a flow against the live simulator | the **maestro** MCP server (see *Authoring flows with the Maestro MCP*) |
| Stop running a whole section in CI | comment its line out of `config.yaml` `flows:` (see `swap_pairs`), and drop it from `skip_auto_rerun` |
| Understand CI pass/fail gating | `pipeline-gate` job (build, both canaries, every shard, auto-rerun) |
| File a task / name a branch for autotest work | *Task & branch workflow for autotest fixes* below |

---

## Shards & wallets (`config.yaml`)

There is one cluster, `multichain`, and one simulator build (CI merges the secret
`MAESTRO_FEATURE_FLAG_OVERRIDES` with `ci/multichain-flags.json` into
`FlagsOverride.json`). `ci/multichain-flags.json` forces
`disable_battery_crypto_recharge_module=false`, which `DefaultBootConfiguration.json`
ships `true` and which hides the crypto recharge entry the `ton_battery` flows drive.

```yaml
clusters:
  multichain:
    gate_pipeline: true
    build_artifact: maestro-ios-tonkeeper-app-multichain
    feature_flags_file: ci/multichain-flags.json
    ton_wallet_shards: [ ton_battery, ton_browser, … ]
    flows: [ flows/multichain/<section>/* , ... ]
```

- A **shard** = one section folder `flows/multichain/<section>/`; shard id = the bare
  section name (`backup`, `send`, `ton_staking`). Every listed folder **must exist on
  disk** or discovery fails.
- A shard runs on **one funded wallet**: `run_maestro_shard.sh` primes the simulator
  pasteboard once per shard and `launch_app_ensure_*` imports once, then every flow of
  the shard reuses that wallet. Two seeds exist:
  - **multichain seed** (`MAESTRO_MC_WALLET_MONEY*`) — the default; preamble
    `steps/launch_app_ensure_multichain_wallet.yaml`. Sections: `backup`, `portfolio`,
    `wallet`, `import`, `battery`, `swap_common`, `send`, `trade`, `staking`.
  - **TON seed** (`MAESTRO_WALLET_WITH_MONEY*`) — a legacy TON wallet imported on the
    same multichain build (`steps/launch_app_ensure_ton_wallet.yaml`: same import
    entry, `Choose wallet → TON wallet`). Sections carry the `ton_` prefix and are
    listed under `ton_wallet_shards`: `ton_battery`, `ton_browser`, `ton_collectibles`,
    `ton_staking`, `ton_tonconnect`, `ton_trade`, `ton_transactions`.
  Discovery emits the choice as `wallet: ton | multichain` in the matrix and the
  workflow maps the secrets per shard, so a flow always reads its own wallet as
  `WALLET_WITH_MONEY` / `WALLET_WITH_MONEY_ADDR`. Never mix seeds inside one section.
- The same-named `tonstakers_*` flows in `staking` and `ton_staking` are both kept on
  purpose: the multichain versions were rewritten for the multichain home (different
  locators, no API asserts), the TON versions check the same screens on a legacy wallet.
- **Create wallet creates a multichain wallet.** `steps/wallet/create_multichain_wallet.yaml`
  is the only create step; there is no TON-only create path anymore.
- Optional `skip_auto_rerun: [<section>, …]` — those shards still run the first attempt
  (+ in-shard per-flow retry) but are excluded from `maestro-rerun-failed-shards`. Used
  for long pair matrices.
- **`swap_pairs` is parked** — the section is commented out of the `flows` list, so CI
  does not run it. The flows stay on disk; re-add the `flows/multichain/swap_pairs/*`
  line together with `skip_auto_rerun: [swap_pairs]` to bring it back.
- `scripts/ci/discover_maestro_clusters.py` parses this file into the GHA matrix
  (shard `id` / `path` / `label` / `wallet` / `skip_auto_rerun`, build artifact,
  feature-flag overlay).

---

## Directory layout

```
maestro_ui_tests/
├── config.yaml                # shard definitions + wallet per shard (source of the CI matrix)
├── flows/                     # the actual test cases, one *.yaml per case
│   ├── multichain/<section>/  # multichain-seed shards (backup, wallet, portfolio, import,
│   │                          #   battery, swap_common, send, trade, staking;
│   │                          #   swap_pairs on disk but parked out of config.yaml)
│   ├── multichain/ton_<section>/ # TON-seed shards (ton_battery, ton_browser, ton_collectibles,
│   │                          #   ton_staking, ton_tonconnect, ton_trade, ton_transactions)
│   └── canary/<wallet>/       # one import-to-home smoke per seed; gates the matrix, not a shard
├── steps/                     # reusable subflows (runFlow targets), e.g.
│   ├── launch_app_ensure_multichain_wallet.yaml / launch_app_ensure_ton_wallet.yaml
│   ├── import_wallet_multichain.yaml / import_wallet_ton.yaml (+ import_wallet_ton_v3/v4 for the import shard)
│   ├── wallet/create_multichain_wallet.yaml   # the only create-wallet path
│   ├── close_home_overlays.yaml       # dismiss stories + home banners (unblocks scroll)
│   └── password/, mnemonic/, history/, wallet/, trade/, …
├── service/                   # on-chain assertion subflows (runScript + assert)
│   ├── account/, history/, swap/
├── scripts/                   # helpers, split by execution context
│   ├── api/                   # device JS: TonAPI GET helpers (see "API scripts" below)
│   ├── utils/                 # device JS: formatter.js, short_addr.js,
│   │                          #   check_history_time.js, parse_mnemonic.js
│   └── ci/                    # runner-side helpers (Python + one shell):
│       ├── maestro_log_parse.py            # shared log-parsing module (imported by the rest)
│       ├── test_maestro_log_parse.py       # unittest; the discover job runs it
│       ├── discover_maestro_clusters.py    # config.yaml → GHA matrix (shards + wallet)
│       ├── sync_api_runtime.py             # stamp shared HTTP runtime into api/*.js
│       ├── write_maestro_flags_override.py # merge feature-flag JSON for a build
│       ├── list_failed_*.py / *_summary.py / write_maestro_github_retry_state.py
│       └── simulator_pbcopy_phrase.sh      # push PHRASE/WALLET_WITH_MONEY to sim UIPasteboard (import shard uses TON_v4)
└── ci/
    ├── multichain-flags.json          # merged into FlagsOverride.json like disable_swap
    ├── run_maestro_shard.sh           # first attempt + per-flow retry for one shard
    ├── run_maestro_failed_paths.sh    # rerun only specific failed flows
    ├── native_token_env.sh            # GRAM/TON token strings passed via -e
    ├── write_maestro_shard_summary.sh
    └── slack_bot/                     # Slack status message (see its own README.md)
```

---

## How a flow runs

`ci/run_maestro_shard.sh` runs one shard: it copies the funded wallet phrase to the
simulator pasteboard, then calls `maestro test <FLOW_DIR>` with these `-e` variables
(defined/forwarded by the CI job; secrets come from repo secrets):

| `-e` var | Source | Used for |
| --- | --- | --- |
| `PASSWORD_KEY=5` | literal | passcode digit taps |
| `NATIVE_TOKEN_DISPLAY_TEXT` / `NATIVE_TOKEN_SHORT_TEXT` | `ci/native_token_env.sh` | token name assertions (GRAM …) |
| `MNEMONIC_PHRASE` | `MAESTRO_MNEMONIC_PHRASE` | wallet import |
| `WALLET_WITH_MONEY` / `WALLET_WITH_MONEY_ADDR` | `MAESTRO_MC_WALLET_MONEY*`, or `MAESTRO_WALLET_WITH_MONEY*` for `ton_wallet_shards` | the shard's funded wallet (mapped per shard by `matrix.wallet`) |
| `auth` | `MAESTRO_AUTH` | TonAPI bearer token for `scripts/api/**` |
| `RECIEVE_WALLET`, `TESTNET_MNEM` | secrets | receive/testnet flows |
| `TON_v4` | `MAESTRO_TON_V4` | `import` shard: v3/v4 TON wallet phrase (that shard primes UIPasteboard with this; Maestro `setClipboard` is not enough on iOS) |

Flows reference shared steps with **relative** `runFlow`, e.g. from
`flows/multichain/<section>/x.yaml` the steps dir is `../../../steps/…`.

**Locators:** prefer stable `accessibilityIdentifier` ids over visible text.
Add missing ids in the app rather than guessing on-screen text or geometry.
Adding one changes native code, so it needs a rebuild + reinstall before a flow can match it.
A screen whose title repeats the title of the screen behind it (the collectibles filter
over the collectibles list) cannot be left by matching that text — the tap silently stays
put and every following assertion passes vacuously. `DefaultModalCardHeader`'s back button
takes `backAccessibilityIdentifier`; the collectibles screens expose it as `header_back`.

**Buttons that stay visible while disabled** (native swap `native_swap_continue`,
multichain swap `swap_continue`) must be waited on with `enabled: true`, not just
`visible`. Their tap handler guards on the same state the enabled flag reflects, so a tap
fired early is a silent no-op and the *next* wait is what fails, minutes later and far
from the cause.

**Never use percentage / absolute coordinates** for `tapOn` / `swipe`
(`point: 25%,50%`, `start: "88%, 25%"`, etc.). CI and local runs use random
iPhone/iPad simulator sizes; percentage geometry that works on one device
misses the target on another. Always bind to:
- `id:` (`accessibilityIdentifier`) — preferred
- visible `text:` / regex only when an id is impractical
- `swipe.from.id` / `scrollUntilVisible.element` (id or text) — never bare `%` points

**Scroll gotcha:** the stories popup + home banners block scrolling — call
`steps/close_home_overlays.yaml` after landing on Home.
**Tooltip gotcha:** a hint (`id: tooltip`, e.g. "Add to favorites" on first open of an
asset screen) sits behind a full-screen dismiss control, so the next tap anywhere only
closes the bubble and never reaches its target. Call `steps/dismiss_tooltips.yaml`
before the first tap on a screen that can show one — do not "tap twice", which would
hit the freshly opened content on runs where the tooltip was already consumed.
**Amount strings:** watch thin space (`\u2009`) vs normal space in `+ 0.89 tsTON`
style assertions; match what the app actually renders. The separator is not a
style choice — `SimplifiedAmountFormatter` uses a plain space only when the ticker
is pure ASCII latin (`GRAM`, `BTC`) and a thin space for everything else (`USD₮`,
`₽`, `%`). An assertion built for one shard therefore breaks on another ticker, so
join with `"[ \u2009]"` instead of `" "` when the step is shared.

**Waiters & timeouts:** an `extendedWaitUntil` timeout is a *ceiling*, not a
budget — it returns as soon as the element appears, so a healthy run never spends
it. But every ceiling is time a *stuck* run burns before failing, and with ~17
shards each running its section on every push, generous ceilings dominate the
suite's wall time (`swap_pairs` / `send` were parked minutes on 180s waits that
never fired). Rules:
- Default to a **tight** timeout that comfortably covers the happy path on a cold
  CI simulator; think in seconds, not minutes. Most UI transitions settle in
  1–6s; a screen behind balance load or a signed on-chain action gets 10–15s.
- **Anything above 15s must be agreed with the task owner before you write it**,
  and carries a one-line comment saying *why* that element genuinely needs longer
  (e.g. broadcast settlement, first cold launch). No silent 30s/60s/180s ceilings.
- `waitForAnimationToEnd` is close to a *fixed* pause (it waits out the timeout
  when the UI keeps ticking), so keep these ≤ ~3s. Prefer an `extendedWaitUntil`
  on the next real element over a long blind animation wait.
- Shared steps (`steps/**`) run across many shards — a timeout you bump there
  multiplies. Change it deliberately, not to paper over one flaky flow.

---

## Task & branch workflow for autotest fixes

Autotest work (fixing red flows, stabilising flakes, CI config for the suite) is tracked
in Linear: team **Tonkeeper (TK)**, project **[QA] Maestro**. One CI incident → one issue
covering all its failures, root cause per flow spelled out in the description; keep
"verified" (build, syntax, tooling) separate from "not verified" (a flow that has not run
end-to-end against the CI wallets) — the real acceptance check is a `workflow_dispatch`
of *Maestro UI Tests* with the relevant cluster. Attach the failing run URL.
An agent files the issue via the Linear MCP (needs corporate VPN + one-time OAuth).

Branches follow the repo-wide `author/TASK/description` scheme enforced by the
`commit-msg` hook — e.g. `pbezv/TK-3446/fix-maestro-ton-state`:

- `author` — your short handle (as in your existing branches);
- `TASK` — the Linear id (`TK-….`); `NOISSUE-0000` only for changes that genuinely have
  no ticket;
- the hook prefixes every commit message with the task id from the branch name, so never
  add it by hand. If it stops being appended, rerun `make -C ios hooks`.

Do not use Linear's suggested `feature/tk-…` branch name — the hook rejects any branch
that is not three `/`-separated segments.


## Authoring flows with the Maestro MCP

`maestro mcp` (Maestro 2.4+) exposes the device to an agent, so a flow can be written
against the *real* view hierarchy instead of guessed locators. It is declared in
`.mcp.json` / `.cursor/mcp.json` / `.codex/config.toml` as
`ios/scripts/tools/maestro.sh mcp --working-dir=ios/maestro_ui_tests`, so every flow path is
written the same way as in `config.yaml` (`flows/multichain/<section>/x.yaml`,
`steps/…`). It talks to whatever simulator is already booted — it does not build the
app; use `make -C ios compile` (or an existing build) and install it first.

Authoring loop:
1. `list_devices` → the iOS `device_id`. **Always pass it explicitly**: with an Android
   emulator also running, an omitted device silently picks the wrong platform.
2. `launch_app` (`com.jbig.tonkeeper`), drive to the screen under test with `run_flow`
   (ad-hoc YAML) or the `tap_on` / `input_text` / `back` shortcuts.
3. `inspect_view_hierarchy` → CSV of `bounds` + `attributes`. `resource-id` is the
   `accessibilityIdentifier` to use as a locator; `accessibilityText` / `text` are the
   text fallback. Missing id ⇒ add it in the app, per *Locators* above.
4. Write the flow under `flows/**`, then `check_flow_syntax` and `run_flow_files` it.

Notes:
- `flow_files` is a **comma-separated string**, not a JSON array (`"a.yaml,b.yaml"`).
- `run_flow` writes its YAML to a temp file, so a relative `runFlow:` inside ad-hoc YAML
  resolves against that temp dir, not `--working-dir`. Reference shared steps by absolute
  path there, or inline them. `run_flow_files` resolves relative paths as expected.
- Pass the shard's `-e` variables via the `env` object — a flow reaching
  `MNEMONIC_PHRASE`, `WALLET_WITH_MONEY`, `auth`, `PASSWORD_KEY` … fails without them
  (see the `-e` table above). `simulator_pbcopy_phrase.sh` still has to prime
  UIPasteboard for import flows.
- `Failed to connect to /127.0.0.1:<port>` means a stale iOS driver: another Maestro
  client (Maestro Studio, an orphaned `xcodebuild test-without-building`) owns the
  port. One plain `maestro test` re-establishes it; don't retry the MCP call in a loop.
- A local import that leaves the phrase fields empty after `Paste` is almost always the
  simulator pasteboard being re-synced from the Mac clipboard between `simctl pbcopy`
  and the tap (copying anything on the host is enough). Turn the sync off for local runs:
  `defaults write com.apple.iphonesimulator PasteboardAutomaticSync -bool false`, then
  restart Simulator.app. A driver that dies mid-run with `isScreenStatic … code: 500` is
  the same stale-driver story as above — usually Maestro Studio running alongside.
- The MCP is for authoring and spot-checks only. A flow is done when it passes through
  the CI entrypoints (`ci/run_maestro_shard.sh`), which own the `-e` wiring and retries.

---

## API scripts & the shared HTTP runtime (codegen)

Flows assert on-chain state by calling TonAPI from JS in `scripts/api/**` (via
`runScript`). Maestro's `runScript` has **no import mechanism** — each script runs
isolated; only `output` crosses steps. So the shared HTTP helpers can't be a module.

Instead:
- `scripts/api/_api_runtime.js` is the **single source of truth** (`_httpGetJSON`,
  `_httpGetJSONOrNull`, `_sleep`, `_withRetry(fn, attempts, delayMs)` — errors and a
  per-response log line include the full URL + HTTP status).
- It is stamped verbatim into every consumer between markers:

  ```js
  // >>> api-runtime (generated …; DO NOT EDIT — run `make maestro_api_sync`)
  … helpers …
  // <<< api-runtime
  ```

- Everything below the markers is hand-written (URL build + response parsing).

Workflow:
```sh
# edit scripts/api/_api_runtime.js, then:
make -C ios maestro_api_sync    # stamp into all consumers
make -C ios maestro_api_check   # verify in sync (CI runs this in discover-maestro-clusters)
```

---

## CI pipeline (`.github/workflows/maestro-ui-tests.yml`)

Nightly `schedule` + manual dispatch (no inputs). Jobs:

1. **discover-maestro-shards** — parse `config.yaml` → matrix (`shards`,
   `build_artifact`); also runs `sync_api_runtime.py --check` and the CI tooling
   unit tests.
2. **maestro-build** — one compile of the simulator app with `FlagsOverride.json`
   built from the secret `MAESTRO_FEATURE_FLAG_OVERRIDES` + `ci/multichain-flags.json`.
   Composite actions in `.github/actions/*maestro*` do checkout → keys → build →
   artifact.
3. **unit-tests** — reuses `.github/workflows/unit-tests.yml` with
   `non_blocking: true` (runs in parallel, does **not** gate).
4. **maestro-canary** — a two-entry matrix (`canary – multichain`, `canary – ton`),
   one import-to-home smoke per seed (`flows/canary/<wallet>/`, deliberately outside
   the `config.yaml` globs so it never becomes a shard). Two entries because the
   pasteboard is primed once per shard run, so one job cannot import both seeds. Gates
   the shard matrix: an app-wide wallet-setup breakage fails one cheap job instead of
   burning every shard's timeout budget. The canary is checked by the pipeline gate
   explicitly, because its failure *skips* the matrix and skipped jobs otherwise count
   as pass.
5. **maestro-ui-tests** — matrix of shards; job names render as `shard – <label>`.
   `matrix.wallet` maps `MAESTRO_WALLET_WITH_MONEY*` to the TON or multichain seed.
   Each shard does first attempt + per-flow retry (`run_maestro_shard.sh`).
6. **discover-failed-shards** (`if: always()`) — collect failures into the rerun
   matrix (id/path/wallet). When **more than half** of the discovered shards failed,
   the failure is systemic and the auto-rerun is skipped entirely — a rerun cannot fix
   an app-wide breakage, it only doubles the bill.
7. **maestro-rerun-failed-shards** — auto-rerun failed shards (wallet-aware secrets).
8. **pipeline-gate** — the single required status.
9. **maestro-slack-notify** — posts a status message with every shard + unit tests.

**Retry layers:** per-flow retry inside a shard → auto-rerun job across failed
shards → GitHub's own workflow re-run (prior failed state is downloaded and reused).

**Screen recordings:** every shard records `simulator-run.mp4`, but a passing
run deletes it before upload — the video is only worth its storage when there
is a failure to debug.

---

## The suite's build locally

The app is unconditionally multichain now, so no `FlagsOverride.json` override
is needed for that. To reproduce a CI-only override locally (e.g.
`disable_battery_crypto_recharge_module`), copy the relevant key from
`ci/multichain-flags.json` into `ios/Keeper/Resources/FlagsOverride.json` and
keep the local change from being committed:
```sh
git update-index --skip-worktree ios/Keeper/Resources/FlagsOverride.json
# undo before a pull that touches the file:
git update-index --no-skip-worktree ios/Keeper/Resources/FlagsOverride.json
```

---

## Conventions

- One test case per `flows/**/*.yaml`; shared logic goes to `steps/**` or `service/**`.
- Prefer `accessibilityIdentifier` ids as locators; add them in the app when missing.
- **Forbidden:** percentage / absolute screen coordinates for taps and swipes
  (`point: X%,Y%`, `start`/`end` with `%`). Tests run across random simulator
  sizes — coordinate recipes only work on the device they were recorded on.
  Use `id:` / text locators and `swipe.from.id` instead.
- No throwaway comments in flows/scripts; keep intent-only notes.
- Don't hand-edit the `// >>> api-runtime` blocks — edit the source + `make maestro_api_sync`.
- A flow that catches a product bug stays enabled and red; document the bug in the
  flow header instead of relaxing the assertion.

---

## Known product bugs kept red

| Flow | Failing check | Bug |
| --- | --- | --- |
| `flows/multichain/trade/core_tokens_open_details.yaml` | BNB → `Transaction history` | Asset details show no history section for BNB even though the wallet holds BNB and has BSC activity; the wallet History tab also offers no BSC filter. |

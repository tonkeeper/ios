# Local response mocks (mitmproxy)

`mock.py` is a mitmproxy addon that serves JSON fixtures per scenario and passes
everything else through to the real backend. **Local only** — Maestro Cloud and CI
cannot reach the proxy. The debug build has no certificate pinning and standard ATS,
so a CA trusted by the simulator is all it takes; no app change is needed.

Only `mock.py` and this README are versioned. `scenarios/` and `_recorded/` are
gitignored: fixtures describe backend states for a specific ticket and stay on the
tester's machine (and are referenced from the QA report), not pushed.

## Run

```bash
# one case behind a scenario; the runner starts mitmdump, routes the simulator
# through it and restores everything afterwards
maestro_ui_tests/tools/qa_run_mock.sh battery_negative_two_refunds booted \
  flows/local/battery/battery_refund_state.yaml two_refunds build/maestro-qa/$(date +%F)/tk-2894 \
  -e EXPECT_CHARGES="-3 charges" -e OUT=build/maestro-qa/$(date +%F)/tk-2894/two_refunds

# record real responses of a host into mocks/_recorded/ to start a new fixture
# (also the only way to see the app's request bodies — the iOS build has no network log)
mitmdump -q --mode local:Keeper -s ../shared/tools/maestro/mock.py --set record=battery.tonkeeper.com
```

`mitm.log` in the case folder lists every `MOCK HIT` so the report can prove the
fixture was actually served.

## How the simulator reaches the proxy

The simulator has no proxy setting of its own — it inherits the Mac's. Two ways,
picked by `MOCK_MODE` in `tools/qa_run_mock.sh` (default `auto`):

| Mode | What happens | Needs |
|---|---|---|
| `local` (preferred) | `mitmdump --mode local:Keeper` intercepts only the `Keeper` process through mitmproxy's macOS redirector; nothing else on the Mac is touched | "Mitmproxy Redirector.app" in `/Applications`, approved once as a network extension (mitmproxy docs → "Local redirect mode" → macOS) |
| `system` | the macOS web + secure web proxy of `$QA_NET_SERVICE` (default `Wi-Fi`) is set to `127.0.0.1:$MOCK_PORT` for the run and restored to the previous state afterwards | `networksetup` — may prompt for an administrator password; every app on the Mac goes through the proxy while the mock is up |

`auto` = `local` when the Redirector is installed, else `system`. A run killed before
the runner restored the proxy leaves the Mac without network in `system` mode:
`networksetup -setwebproxystate Wi-Fi off; networksetup -setsecurewebproxystate Wi-Fi off`.

## Simulator prerequisites (once per simulator)

```bash
maestro_ui_tests/tools/install_mitm_ca.sh <udid>   # generates the CA if missing, then simctl keychain add-root-cert
```

If a mocked run shows `Client TLS handshake failed … Keeper` in `mitm.log`, the CA is
not trusted on this simulator — rerun the script for that UDID. TLS failures for
Apple system hosts through the proxy are expected and harmless.

## Layout

```
mocks/
├── mock.py                       # addon: scenario serving + record mode
├── scenarios/<scenario>/<host>/<path with "/" → "__">.json
│                              …/<same>.meta.json   # optional {"status": 503, "delay_ms": 1500, "headers": {…}}
│                              …/GET__<path>.json   # method-specific match (optional prefix)
│                              …/POST__<path>__<needle>.json   # only when <needle> is in the query/body
└── _recorded/<host>/<METHOD>__<path>.json          # raw captures from --set record
```

Query strings are ignored when matching. Everything without a fixture passes through.

## Hosts worth knowing

| Host | Feeds |
|---|---|
| `keeper.tonapi.io` | TON balances, jettons, staking pools/positions, history |
| `multi.tonkeeper.com` | multichain wallet assets and prices (`/api/v1/wallets/<id>/assets`) |
| `battery.tonkeeper.com` | battery balance, purchases, config |
| `boot.tonkeeper.com` / keys | remote feature flags and boot configuration |
| `anonymous-analytics.tonkeeper.com` | Aptabase analytics — record mode is the way to see the event bodies |

Adding a scenario: copy the closest folder, edit the JSON, add a row to the ticket's
report, and note in the fixture's `.meta.json` or in the flow header which real
response it was derived from (`_recorded/` keeps the capture).

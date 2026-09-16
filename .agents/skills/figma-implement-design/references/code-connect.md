# Code Connect Mappings

Detail for the two-phase handling of Code Connect in this repo: Step 3 detects Figma component or instance nodes, sets `hasDesignSystemComponents`, and records returned hints without loading this file. Load this file in Step 5 only when that flag is true and after the relevant code owners and UI stacks are known. Do not load it when the selection contains no purple design-system components.

## Phase 1 — collect (Step 3)

Code Connect hints usually arrive inside the `get_design_context` response. At this point Step 3 should already have recorded the relevant root and descendant mappings; use that record instead of repeating the context call unless the target or parameters changed.

Every initial and descendant `get_design_context` call in this repo must use `clientFrameworks="SwiftUI,Swift UIKit"` and `clientLanguages="Swift"`. Missing hints after that full iOS coverage mean only that the response returned no matching mapping; they do not prove that no reusable project component exists.

Do not call `get_code_connect_suggestions` to prove that mappings are absent — that tool belongs to the mapping-creation task, not to screen implementation.

If `get_design_context` returns a Figma-authored mapping question instead of design context, relay the requested question and follow the user's answer exactly. Do not infer consent, and do not disable Code Connect merely to suppress the prompt.

## Phase 2 — validate (Step 5)

When `get_design_context` left a relevant mapping unclear, call the read-only `get_code_connect_map` for that component or selection with `codeConnectLabel: "SwiftUI"` or `codeConnectLabel: "Swift UIKit"`, matching the stack established for that candidate's code owner. When a component subtree may legitimately mix stacks, query the original selection once for each label to inventory descendant records before validating them individually.

This is a one-time pre-edit lookup, not part of the render/fix loop. Re-run it only when the target node, owner stack, or mapping itself changed; it reads the mapping registry and cannot validate the current implementation or rendered result.

A mapping is a reuse signal, not an authority: it does not override module boundaries and it does not prove the mapped code still exists. Check each of these before reuse:

- **Source** — the mapped file and symbol still resolve in the current repository
- **Semantics** — the component matches the Figma component's purpose, not only its appearance
- **API** — its public API expresses the required variants, states, and configurable content without invented parameters or one-off hacks
- **Stack** — a `Swift UIKit` mapping is usable only through an established project bridge, never through a wrapper created solely to satisfy Code Connect
- **Dependencies** — the owner module can import it without pulling wallet/domain dependencies, and without making a previewable target reach the crypto graph

## Outcomes

When every check passes:

- a valid mapped root means reuse or update that view instead of creating a duplicate
- a valid mapped descendant means use that component directly and implement only the surrounding layout
- mapped component usage takes priority over recreating the component from raw Figma geometry

When a check fails, treat the mapping as stale or inapplicable, fall back to the normal repo reuse search, and report the specific mismatch in the handoff.

When no mapping exists, still run the normal reuse search. Absence of Code Connect never implies a new component is needed.

## Never map as a side effect

Never create, update, or publish a mapping while implementing a screen. Mapping creation is a separate design-system action with an external write. When it is requested on its own:

- require a published, stable, reusable component with a clear property-to-API correspondence
- call `get_code_connect_suggestions` with `excludeMappingPrompt: true` and use the selected component's returned `mainComponentNodeId`, not the supplied frame or instance ID
- call the read-only `get_context_for_code_connect` for a returned `mainComponentNodeId` when variants, properties, or nested structure are needed to validate the property-to-API correspondence
- establish the code owner's actual stack and select `SwiftUI` or `Swift UIKit` accordingly
- call `get_code_connect_map` for that `mainComponentNodeId` and label; validate an existing mapping instead of overwriting it
- confirm the intended component match before the external write
- create the confirmed mapping with `add_code_connect_map`, passing `fileKey`, the returned `mainComponentNodeId` as `nodeId`, the confirmed `componentName`, the resolved `label`, and the repository-relative `source`
- omit `template` and `templateDataJson`; do not proactively load the template-only `figma-code-connect` skill or generate `.figma.ts`/`.figma.js` files for this iOS repository. If the client loads that skill automatically, use only compatible discovery and read-only component-context guidance, and do not follow its template creation or publishing steps
- verify the saved record with `get_code_connect_map`

### Mapping a component tree

When the user explicitly requests mappings for a root and its nested components:

1. Call `get_code_connect_map` for the original selection with both `codeConnectLabel: "SwiftUI"` and `codeConnectLabel: "Swift UIKit"` to inventory already mapped root and descendant records.
2. Call `get_code_connect_suggestions` with `excludeMappingPrompt: true` for the original selection to collect only the unmapped published candidates, then deduplicate those suggestions by `mainComponentNodeId`.
3. Use `get_context_for_code_connect` for candidates whose variants, properties, or nested structure are needed to establish an exact code match.
4. Resolve and validate the code owner, stack, source, symbol, semantics, API, and dependencies for every unmapped candidate, and validate every existing record returned in Step 1. Skip design-only wrappers, assets, or primitives without an exact stable code component; never invent a code wrapper merely to complete the tree.
5. Present existing records and proposed root and descendant matches together for confirmation. Consent for the root does not imply consent for every descendant.
6. Save approved simple mappings with `send_code_connect_mappings`, passing `fileKey`, the original selection as the top-level `nodeId`, `clientFrameworks: "SwiftUI,Swift UIKit"`, `clientLanguages: "Swift"`, and one entry per approved candidate containing `componentName`, its `mainComponentNodeId` as `nodeId`, the resolved `label`, and the repository-relative `source`. Omit `template` and `templateDataJson` from every entry; mixed `SwiftUI` and `Swift UIKit` labels are allowed when they match the respective code owners.
7. Verify each approved `mainComponentNodeId` and label with `get_code_connect_map`; report partial failures instead of treating the batch as atomic.

An existing `hasTemplate: true` record is not stale merely because it has a template. It can provide useful property-aware snippets that a simple mapping cannot. Validate its source, symbol, generated snippet, and current API like any other mapping. If it is genuinely stale or invalid, show the user its label, component name, source, template status, and the reason a replacement is needed. Never disconnect it automatically: require separate explicit confirmation for the destructive disconnect, distinct from consent to create the replacement, then verify that the old record is absent before saving the simple mapping. `add_code_connect_map` does not overwrite an existing connection.

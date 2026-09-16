---
name: "figma-implement-design"
description: "Implement or compare Figma designs as SwiftUI/UIKit in this iOS repo using the Figma MCP design-to-code flow, Tonkeeper module boundaries and tokens, and rendered SwiftUI-preview validation. Use when the user provides a figma.com design URL or node ID, asks to implement or match a mockup, or wants to compare a preview with Figma. Requires the figma MCP server."
---

# Implement Design

## Overview

Translate Figma designs into production-ready iOS code with high visual fidelity while preserving project tokens, platform behavior, accessibility, and module boundaries.

## Prerequisites

- Figma MCP server must be connected and accessible
- A node-specific Figma design URL such as `https://figma.com/design/:fileKey/:fileName?node-id=1-2` is required unless the file key and node ID are already established in the conversation
  - `:fileKey` is the file key
  - `1-2` is the node ID (the specific component or frame to implement)
- Project should have an established design system or component library (preferred)
- Xcode MCP, an Xcode window for this worktree, and a scheme containing the owner target are required to claim snapshot comparison. Without them, implementation can proceed, but the handoff must state that snapshot comparison was not performed and the visual loop was not completed.

## Required Workflow

Follow these steps in order. Apply conditional branches only when relevant, and use the documented fallback when an optional tool is unavailable.

### Step 0: Set up Figma MCP (if not already configured)

The `figma` MCP server is already declared in the repo configs (`.mcp.json` for Claude Code, `.cursor/mcp.json` for Cursor, `.codex/config.toml` for Codex), so no manual server registration is needed. Each user only has to complete the one-time OAuth login.

When an MCP call fails because Figma MCP is not connected, pause and log in per the instructions for the current agent:

- **Claude Code:** run `/mcp` and complete the OAuth login for `figma`.
- **Codex CLI:** run `codex mcp login figma`.
- **Cursor:** complete the OAuth login from Settings → MCP.

The login may require an agent restart. Finish the answer, state that requirement, and resume from Step 1 on the next attempt.

### Step 1: Get Node ID

When the user provides a Figma URL, extract the file key and node ID to pass as arguments to MCP tools.

**URL formats:**

- `https://figma.com/design/:fileKey/:fileName?node-id=1-2`
- `https://figma.com/design/:fileKey?node-id=1-2#comment-id`
- `https://figma.com/design/:fileKey/branch/:branchKey/:fileName?node-id=1-2`

**Extract and preserve:**

- **File key:** `:fileKey` (the segment after `/design/`); for a branch URL, use `:branchKey`
- **Node ID:** `1-2` (the value of the `node-id` query parameter)
- **Comment ID:** the optional URL fragment after `#`; it identifies an ordinary Figma comment thread and is not part of the node ID passed to MCP tools

**Example:**

- URL: `https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15`
- File key: `kL9xQn2VwM8pYrTb4ZcHjF`
- Node ID: `42-15`

### Step 2: Fetch Design Context

Before calling `get_design_context`, load the official `/figma-design-to-code` skill when the client provides it; otherwise read `skill://figma/figma-design-to-code/SKILL.md` from the Figma MCP resources. This repo skill specializes that general workflow with Tonkeeper-specific placement, resources, previews, and verification.

Make `get_design_context` the first Figma inspection call and the primary source for the implementation. When the exposed tool schema accepts `skillNames`, pass the matching skill marker:

```
get_design_context(
  fileKey=":fileKey",
  nodeId="1-2",
  clientFrameworks="SwiftUI,Swift UIKit",
  clientLanguages="Swift",
  skillNames="figma-design-to-code"
)
```

When the guidance was loaded from the MCP resource, pass `skillNames="resource:figma-design-to-code"` instead. If the client automatically loaded `figma-code-connect` for an explicit mapping task and its compatible discovery or read-only context guidance is being followed, append that installed or `resource:`-prefixed marker to the comma-separated value. Omit `skillNames` when the exposed schema does not accept it. Always pass `clientFrameworks="SwiftUI,Swift UIKit"` for initial and descendant context calls in this repo, even after the root owner is known. The schema describes this field as telemetry, while some remote deployments may also use it when selecting Code Connect hints; listing both supported iOS stacks avoids hiding a cross-stack descendant mapping. Standalone map lookup still uses the candidate's resolved `codeConnectLabel` in Step 5.

Treat the returned code as a reference to adapt, not production Swift. The response includes a screenshot and structured data such as:

- Layout properties (Auto Layout, constraints, sizing)
- Typography specifications
- Color values and design tokens
- Component structure and variants
- Spacing and padding values

When the context names Figma variables but does not provide enough information to match them to project tokens, call `get_variable_defs` for the same node. Use its output for semantic token lookup, not to introduce raw hex values when an existing project token applies.

**If the response is too large or truncated:**

1. Run `get_metadata(fileKey=":fileKey", nodeId="1-2")` to get the high-level node map
2. Identify the specific child nodes needed from the metadata
3. Fetch individual child nodes with `get_design_context`, reusing `clientFrameworks="SwiftUI,Swift UIKit"`, `clientLanguages="Swift"`, and the same schema-supported `skillNames` value as the primary call

#### Collect Figma Comments and Annotations

After the primary context returns:

- inspect the Design/Dev Mode annotations included in `get_design_context`; apply relevant notes according to the official hint priority
- when the supplied URL contains `#comment-id`, preserve the exact URL and inspect that ordinary comment thread, its replies, and resolution state in an authenticated Figma browser session
- when a referenced Dev Mode-only note is absent from the context, inspect the exact node in an authenticated Figma Dev Mode session
- do not use `get_metadata` or Plugin API `node.annotations` to conclude that comments are absent; neither is an ordinary-comment retrieval API
- if no authenticated browser is available for a required comment, ask the user to paste it instead of inferring its content

Treat relevant unresolved comments as implementation context. Apply a comment as a requirement only when its intent and authority are unambiguous; otherwise surface the ambiguity to the user. Separate visual requirements from behavioral ones, and inspect the current flow before changing navigation or interaction.

### Step 3: Detect Design-System Components and Collect Code Connect Signals

Inspect the returned structure for Figma component or instance nodes—the purple design-system components in Figma. If `get_design_context` does not expose node kinds clearly, call `get_metadata` once for the same target after the context call and use its `<component>` and `<instance>` node types; do not infer component status from a layer name or an `I`-prefixed instance path. Only component and instance nodes enter the Code Connect branch; plain frames, groups, text, vectors, and raster assets do not.

Set a `hasDesignSystemComponents` flag when such nodes exist and record relevant root and descendant Code Connect hints before searching for or creating UI components. Do not load `references/code-connect.md` in this step. Existing mappings are a strong reuse signal, but they do not override this repo's module boundaries or prove that a stale mapping is still valid. Missing hints after a context call covering both iOS stacks mean only that no matching mapping was returned; they do not replace the normal project reuse search. Defer standalone map lookup and validation until Step 5 has established each candidate's owner module and UI stack. Do not call `get_code_connect_suggestions` merely to prove that mappings are absent; it belongs to a separate mapping-creation task.

### Step 4: Preserve the Visual Reference

Keep the screenshot returned by `get_design_context` as the source of truth. Call `get_screenshot` with the same file key and node ID only when the embedded screenshot is missing or stale, or when a standalone exact-node reference is needed after fetching child context.

```
get_screenshot(fileKey=":fileKey", nodeId="1-2")
```

Keep one labeled exact-node reference for every target state accessible throughout implementation.

### Step 5: Resolve Ownership and Project Reuse

Read `AGENTS.md` → «SwiftUI Previews» before placement. Preserve a correct existing crypto-free owner. For new or materially reworked UI, reusable component → `TKUIKit`, product screen → `AppUI` or an established crypto-free `<Feature>UI`, and wallet/domain logic → `App`. Do not move unrelated screens solely to imitate the preview architecture. When a move is required, move the touched screen as one cluster, not view-by-view. For Figma validation, map a full-screen frame to matching device geometry and an exact-size component to `.fixedLayout(width:height:)`.

Before moving or deleting an existing screen cluster, inventory all consumers: root views, controllers/assemblies, providers, coordinators, shared models, and settings/onboarding variants. Choose the owner only after this inventory. Preserve each consumer's actions, loading/error states, sensitive-content handling, navigation behavior, and analytics unless the requested design or its captured Figma comments explicitly change them.

After resolving the relevant code owners, read `references/code-connect.md` only when `hasDesignSystemComponents` is true, then follow its validation and consent rules. Do not load that reference when the flag is false.

Follow the same `AGENTS.md` section for preview file structure, package-boundary images, localization, generated resources, and flat preview state.

### Step 6: Download Required Assets

Download only assets that remain necessary after the project reuse search.

For iOS, a Figma asset URL is a download source, not a runtime URL:

- reuse an existing project asset before adding a duplicate
- new vector assets are PDF-only: never import SVG; convert or re-export an SVG-only payload to PDF
- create a matching `<name>.imageset` under `LocalPackages/TKUIKitResources/Sources/TKUIKitResources/Resources/Assets.xcassets`, follow a neighboring `Contents.json` and naming convention, and put the PDF inside it
- download raster artwork or texture into the corresponding `.imageset`
- run `make resources` and use the generated `SwiftUI.Image.TKUIKit`/`UIImage.TKUIKit` API
- do not add an icon package, leave a Figma asset endpoint in production code, or use a placeholder when the real asset is available

### Step 7: Prepare the Preview Environment

After the owner target is known:

1. Ensure Xcode has this worktree's `Tonkeeper.xcodeproj` open (`xed Tonkeeper.xcodeproj`).
2. Use `XcodeListWindows` to get its `tabIdentifier`.
3. Have a human select a scheme containing the owner because `RenderPreview` cannot switch schemes. Use the shared `AppUI` scheme for `AppUI` and `TKUIKit`.

If Xcode MCP is unavailable, continue with implementation, but do not claim snapshot comparison or a completed visual loop. This skill does not impose an automatic compile fallback.

### Step 8: Implement with High Visual Fidelity

Match the Figma reference closely within project conventions, semantic tokens, platform behavior, and accessibility constraints.

**Guidelines:**

- Map Figma color variables to `TKColor` and use themed modifier overloads such as `.foregroundStyle(.textPrimary)`, `.background(.backgroundPage)`, `.fill(.accentBlue)`, and `.stroke(.separatorCommon)`; do not snapshot palette colors into `Color` or `UIColor`
- Map Figma typography to an existing `TKTextStyle` and apply `.textStyle(.h2)`-style APIs; do not rebuild font size, weight, and line height when a token exists
- Keep local Figma-specific layout metrics as scoped constants only when no semantic token exists
- If the correct semantic token resolves differently from Figma, report design-system drift instead of replacing the token with a hardcoded value
- Adjust non-semantic layout metrics minimally to match the reference
- Make preview data deterministic. For randomized production flows, represent target states with flat fixed preview state; inject deterministic inputs into logic only when behavior itself needs testing.
- Stress constrained layouts with the longest representative or localized copy, especially equal-width buttons. Prefer a local compression/layout adjustment over changing a shared component for one screen.
- Preserve iOS accessibility labels, traits, hit targets, and any Dynamic Type behavior already supported by the component. Do not treat preview rendering as Dynamic Type validation: `TKTextStyle` fonts are fixed-size.

### Step 9: Validate Against Figma

Before marking complete, validate the final UI against the Figma screenshot.

**Validation checklist:**

- [ ] Layout matches (spacing, alignment, sizing)
- [ ] Typography matches (font, size, weight, line height)
- [ ] Correct semantic color tokens are used; any Figma difference is reported as design-system drift
- [ ] Interactive states work as designed (pressed, selected, loading, disabled)
- [ ] Device-size and safe-area behavior follows Figma constraints
- [ ] Assets render correctly, including template/original rendering mode and semantic tint
- [ ] Long representative/localized content does not truncate unexpectedly
- [ ] VoiceOver labels present on interactive elements, hit targets ≥ 44 pt

The snapshot validates appearance, not interaction or accessibility behavior. Verify those through code inspection, focused tests, or manual interaction as appropriate.

**iOS (this repo)** — verify by snapshot, not by reading the code. Requires the `xcode` MCP server, the worktree window and scheme prepared in Step 7:

1. `XcodeGlob` with `**/<View>+Previews.swift` → project-organization path (e.g. `AppUI/Sources/AppUI/<Module>/<View>+Previews.swift`; filesystem paths are rejected)
2. `RenderPreview` with that path — `previewDefinitionIndexInFile` selects the N-th `#Preview`; use `.tkPreviewTheme(_:)`, not the Color Scheme variant, for the Tonkeeper theme
3. Render the same logical canvas as the node captured in Step 4:
   - exact-size component → `.fixedLayout(width:height:)` using the Figma node dimensions
   - full-screen frame → matching simulator/device geometry; do not replace device safe areas with `.fixedLayout`
4. Render every materially different state supplied by Figma or changed by the implementation (for example empty, selected, error, loading, and disabled), not only the first preview macro
5. Inspect the returned PNG with the client's image viewer and compare it with the matching reference from Step 4. Compare layout in points when PNG pixel dimensions or scale differ. Separate app-owned content differences from OS-provided status and navigation UI supplied by the selected simulator runtime.
6. Reuse the standard project navigation component when OS-provided UI differs across iOS versions; do not custom-draw a stale OS appearance solely to match a Figma screenshot. Report that variance.
7. Fix and re-render until remaining differences are either resolved or explicitly explained in the handoff.

Once every required preview renders successfully and remaining visual differences are resolved or explicitly explained, the loop is complete.

Match the theme of the Figma frame with `.tkPreviewTheme(.light / .dark / .deepBlue)` as the preview root. `.tkThemed()` follows the theme saved on the machine and `previewVariantOverrides: {"Color Scheme": …}` does not repaint the Tonkeeper palette — neither gives a reproducible render.

New files in a SwiftPM package are picked up automatically — no `pbxproj` edit. If the render fails with `JITError: Runtime linking failure`, the view sits in a crypto-linked module: move it per Step 5 instead of trying to fix the preview.

For preview failures, follow `AGENTS.md` → «SwiftUI Previews» → «Troubleshooting».

## Implementation Rules

- Prefer the smallest change that fits the existing module and design system.
- Extend a matching component only when the new state belongs to its existing abstraction.
- Keep flat view state render-oriented and free of wallet/domain entities.
- Add `public` and `public init` only at actual package boundaries.
- Comments explain only non-obvious constraints or deliberate Figma deviations.

## Reference Examples

- **Canonical reference for an App → AppUI boundary:** the `BackupModule` files under `LocalPackages/AppModules/AppUI/Sources/AppUI/BackupModule/` show render-only screen clusters, flat state, and sibling previews; the matching adapters under `LocalPackages/App/Sources/App/BackupModule/Modules/RecoveryPhrase/` and `RecoveryPhraseCheck/` keep view models and app wiring in `App`. Follow this pattern when that package boundary is already required; do not migrate unrelated screens merely to copy the example. Use it only for architecture and preview wiring—the current task's Figma node remains the visual source of truth.

## Additional Resources

### Reference Files

- **`references/code-connect.md`** — conditional Code Connect handling for Figma component and instance nodes

### Repo Conventions

- `AGENTS.md` → «Colors & Theming (SwiftUI)» — token APIs and palette rules
- `AGENTS.md` → «SwiftUI Previews» — previewable modules, preview files, image and asset boundaries
- `AGENTS.md` → «Localization Workflow» — the `TKLocales` key flow

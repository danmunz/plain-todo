# Plain — Design Refresh Implementation Plan

## Overview

This plan covers the comprehensive visual refresh of Plain, a native macOS todo.txt client. The app is ~95% feature-complete (60 commits, 123 passing tests, ~5,800 lines of app code on `feat/bootstrap-core`). All functional behavior is in place — this work is purely visual.

The refresh is defined by 6 design documents in `docs/design/` covering tokens, component specs, animation choreography, brand, and a prioritized visual audit. The audit defines 4 tiers of work, which this plan respects as the sequencing backbone.

**Approach:** Extract design tokens into a shared module first, then systematically rework each visual layer from foundations (backgrounds, colors, typography) through structural hierarchy (sidebar, headers, bars) to interaction polish (animations, overlays) and finally secondary surfaces (onboarding, empty states, toasts). Every sprint produces a buildable, testable state. All work lives on `feat/design-refresh` branched from `feat/bootstrap-core`.

**Branch strategy:** `feat/design-refresh` from `feat/bootstrap-core`. Atomic commits per task. No merge to parent branch until the full refresh is validated.

**Build/test commands:**
```
xcodegen generate && xcodebuild -project Plain.xcodeproj -scheme PlainApp -destination 'platform=macOS' build
xcodebuild -project Plain.xcodeproj -scheme PlainApp -destination 'platform=macOS' -only-testing:PlainCoreTests -only-testing:PlainAppTests test
```

---

## Sprint 0 — Design Token Foundation (3–4 days)

**Goal:** Create a shared design token layer so all subsequent visual work references tokens, not hardcoded values.

### TASK-001: Create `DesignTokens.swift` with warm gray color scales

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** None
- **Description:** Create `Sources/PlainApp/DesignTokens.swift` containing a `PlainTokens` enum (or similar namespace) with:
  - All 10 light gray steps (`gray.50` through `gray.900`) as `Color` constants
  - All 10 dark gray steps (`grayDark.50` through `grayDark.900`)
  - Adaptive semantic surface tokens (`surface.canvas`, `.sidebar`, `.input`, `.hover`, `.selected`, `.toast`, `.quickAdd`) that resolve light/dark automatically using `Color(light:dark:)` or an asset catalog
  - Adaptive semantic text tokens (`text.primary`, `.secondary`, `.muted`, `.inverse`)
  - Adaptive border tokens (`border.row`, `.section`, `.input`, `.inputFocused`)
  - Selection tokens using system accent at specified opacities
- **Acceptance Criteria:**
  - File compiles with no warnings
  - Every semantic token from `design-tokens.md` § Surfaces, Text, Borders is represented
  - Light and dark mode resolve to the correct hex values from the spec
  - Existing tests still pass (no functional changes)
- **Files:** `Sources/PlainApp/DesignTokens.swift` (new)
- **Tests:** Compile-only. Optionally add a `DesignTokenTests.swift` that spot-checks a few resolved color components in both color schemes.

### TASK-002: Add syntax, priority, and status color tokens

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-001
- **Description:** Extend `DesignTokens.swift` with:
  - Syntax highlighting colors: `syntax.project` (teal), `syntax.context` (violet), `syntax.keyValue`, `syntax.date` — each light/dark adaptive
  - Priority colors: `priority.A` / `.B` / `.C` / `.low` — foreground and `.bg` (10–12% opacity) variants
  - Status colors: `status.overdue`, `.today`, `.completed`, `.conflict`, `.success`, `.destructive`
- **Acceptance Criteria:**
  - All syntax, priority, and status tokens from `design-tokens.md` are present
  - Priority `.bg` variants produce the correct tinted-opacity color
  - Existing tests pass
- **Files:** `Sources/PlainApp/DesignTokens.swift`
- **Tests:** Compile-only.

### TASK-003: Add typography, spacing, and measurement tokens

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-001
- **Description:** Add to `DesignTokens.swift` (or a sibling `PlainTypography.swift` / `PlainSpacing.swift`):
  - All 18 typography tokens from the spec as `Font` values (e.g., `.windowTitle` = 13pt Semibold, `.taskBody` = 14pt Regular, `.priorityBadge` = 12pt Semibold, etc.)
  - Spacing scale: `xs(2)`, `sm(4)`, `md(8)`, `lg(12)`, `xl(16)`, `xxl(24)`, `xxxl(32)` as CGFloat constants
  - Key measurements: sidebar width (220 default, 180–300 range), task row min height (40), input bar height (44), status bar height (28), completion circle diameter (18), priority badge height (20), selection bar width (3), separator thickness (0.5)
  - Corner radii: `none(0)`, `sm(4)`, `md(8)`, `lg(10)`, `xl(12)`
  - Shadow definitions: `toast`, `search`, `quickAdd`, `drag`
  - Opacity tokens: `completedRow(0.45)`, `hoverMenu(0→0.7)`, `disabledControl(0.4)`, `dragPlaceholder(0.3)`, `searchDimmed(0.35)`
- **Acceptance Criteria:**
  - All spacing, typography, radius, shadow, and opacity tokens from the spec are present
  - Constants are organized and documented with their spec origins
  - Existing tests pass
- **Files:** `Sources/PlainApp/DesignTokens.swift` (or split files)
- **Tests:** Compile-only.

### TASK-004: Add animation timing tokens

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-001
- **Description:** Add animation constants:
  - Duration tokens: `fast(0.12)`, `normal(0.2)`, `slow(0.3)`, `pulse(1.0)`
  - Spring parameters: response `0.35`, dampingFraction `0.7`
  - Composite timings: `completion.delay(0.4)`, `completion.strike(0.25)`, `completion.dim(0.2)`, `toast.in(0.2)`, `toast.linger(4.0)`, `toast.out(0.15)`, `searchIn(0.15)`, `searchOut(0.12)`, `quickAdd.in(0.15)`, `quickAdd.out(0.12)`
  - A helper that checks `accessibilityReduceMotion` and returns `.instant` or the real animation
- **Acceptance Criteria:**
  - All animation tokens from `design-tokens.md` and `animation-choreography.md` are present
  - The reduced-motion helper compiles and provides a clean API
  - Existing tests pass
- **Files:** `Sources/PlainApp/DesignTokens.swift`
- **Tests:** Compile-only.

---

## Sprint 1 — Warm Foundations & Syntax Highlighting (1 week)

**Goal:** Replace all stock backgrounds with the warm palette and implement syntax highlighting — the two changes that most transform the app's feel.

**Dependencies:** Sprint 0 complete.

### TASK-005: Replace all backgrounds with warm surface tokens

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-001
- **Description:** In `PlainApp.swift` and `PlainAppScenes.swift`:
  - Set `NavigationSplitView` detail background to `surface.canvas`
  - Set sidebar background to `surface.sidebar`
  - Set input bar background to `surface.input`
  - Remove any `.listStyle(.sidebar)` or `.listRowBackground` that forces system colors — use explicit token fills
  - Apply `surface.canvas` to the main window background
  - Ensure dark mode uses the `grayDark.*` equivalents (should be automatic via adaptive tokens)
  - Apply warm backgrounds in `PreferencesView` (`PreferencesStore.swift`)
- **Acceptance Criteria:**
  - The window no longer uses default macOS gray — it reads as subtly warmer than Finder/Notes
  - Dark mode produces warm dark grays, not cool blue-black
  - Sidebar and content area are visually distinct warm tones
  - All 123 existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`, `Sources/PlainApp/PlainAppScenes.swift`, `Sources/PlainApp/PreferencesStore.swift`
- **Tests:** Existing tests pass. Add a snapshot or manual verification note.

### TASK-006: Update `SyntaxHighlightedText` to use design tokens

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-002
- **Description:** Refactor the existing `SyntaxHighlightedText` view (line ~1315 in `PlainApp.swift`) to:
  - Replace `.teal` with `syntax.project` token
  - Replace `.purple` with `syntax.context` token
  - Replace `.secondary` (on key:value) with `syntax.keyValue` token
  - Replace `.primary` with `text.primary` token
  - Use `type.taskTags` weight (Medium) for `+project` and `@context` segments
  - Use `type.taskMeta` size (12pt) for `key:value` segments
  - Apply `syntax.date` color to creation dates
  - When `strikethrough` is true, apply `opacity.completedRow` to all text
  - Ensure search highlighting still works (the `HighlightedText` path)
- **Acceptance Criteria:**
  - `+project` renders in teal (`#3A8A7A` light / `#5BB8A6` dark), not system teal
  - `@context` renders in violet (`#7B5EA7` light / `#A98BD4` dark), not system purple
  - `key:value` renders in `gray.500`, 12pt
  - All syntax highlight tests in `PlainAppTests` still pass
  - Visual verification: a task like `(A) Call accountant @phone +taxes due:2026-05-29` shows distinct colors for each segment
- **Files:** `Sources/PlainApp/PlainApp.swift` (SyntaxHighlightedText struct)
- **Tests:** Existing `PlainShellModelTests` pass. Consider adding a unit test that verifies attributed string segments have the expected foreground colors.

### TASK-007: Add priority badges to task rows

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-002
- **Description:** In the task row rendering code:
  - Replace any inline text rendering of `(A)`, `(B)`, `(C)` with a badge component
  - Badge spec: letter only (no parens), 12pt Semibold, inside a rounded rect (height 20px, 4px horizontal padding, 4px corner radius)
  - Badge background: `priority.*.bg` (the priority color at 10–12% opacity)
  - Badge text: `priority.*` foreground color
  - For unprioritized tasks, the badge element and its gap collapse to zero width
  - Position: between the completion circle and the task text, with `space.sm` gaps
  - Completed rows: badge remains but at `opacity.completedRow`
- **Acceptance Criteria:**
  - Priority A shows a warm-red pill, B shows amber, C shows blue
  - Unprioritized tasks have no gap where the badge would be
  - Badges are scannable by color alone
  - All existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (task row rendering)
- **Tests:** Existing tests pass. Add a view test or snapshot test verifying badge presence/absence.

### TASK-008: Fix task row layout — single structured row

- **Type:** Implementation
- **Complexity:** High
- **Dependencies:** TASK-006, TASK-007
- **Description:** Restructure each task row to the target layout:
  ```
  [16px pad] [Circle 18px] [4px] [Badge?] [4px] [SyntaxText …] [flex] [DueDate?] [4px] [16px pad]
  ```
  - Remove the duplicate subtitle line (the "raw text" echo below the rendered text)
  - Set minimum row height to 40px, vertically centered
  - Completion circle: 18px diameter, 1.5px stroke, `text.muted` color (or priority color for prioritized tasks)
  - Due date label: right-aligned, 12pt Medium, humanized ("Today", "Tomorrow", "Jun 5", "Overdue"), colored per status (`status.overdue`, `status.today`, `text.muted`)
  - Extract `due:YYYY-MM-DD` from inline text (hide it from the syntax-highlighted body, show it as the due date label)
  - Single-line truncation with `…` by default
- **Acceptance Criteria:**
  - Each row is a single line with the specified anatomy
  - No duplicate text line
  - Due dates appear as humanized labels on the right, not inline
  - Row minimum height is 40px
  - Completed rows show dimmed text with strikethrough + dimmed badge + filled circle
  - All existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (task row, ForEach body)
- **Tests:** Existing tests pass. Update any `PlainShellModelTests` that assert on row content if the removal of the subtitle changes accessibility labels.

---

## Sprint 2 — Row States & Structural Hierarchy (1 week)

**Goal:** Implement hover/selection states on rows and rework sidebar and header hierarchy.

**Dependencies:** Sprint 1 complete.

### TASK-009: Implement row interaction states

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-008
- **Description:**
  - **Hover:** Apply `surface.hover` background on mouse-over, fading in at `anim.fast` (120ms). Track hover with `onHover` or the existing `hoveredRowID` state.
  - **Selected (keyboard):** Replace the stock full-width blue highlight with `selection.bg` fill + a 3px `selection.bar` accent bar on the left edge. This requires removing the default `List` selection style and applying custom selection rendering.
  - **Row separator:** Add a 0.5px `border.row` line at the bottom of each row, inset to align with the task text (not flush left — starts after the circle area).
  - **Combined states:** Hover + selected shows both `selection.bg` and the accent bar, with the ··· menu visible.
- **Acceptance Criteria:**
  - Hovering a row shows a warm background fill, not the system highlight
  - Selected row has a 3px accent bar on the left and a warm tinted background
  - No system blue highlight visible
  - Subtle row separators visible between every row
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass. Manual visual verification.

### TASK-010: Rework sidebar hierarchy

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005
- **Description:** Refactor the sidebar (lines ~85–130 in `PlainApp.swift`) to match the spec:
  - **Section headers** ("SMART FILTERS", "+PROJECTS", "@CONTEXTS", "ARCHIVE"): 11pt Bold, allcaps, 1.2pt letterspacing, `text.muted` color. 16px left padding, 8px bottom margin.
  - **Sidebar items**: `SidebarRow` uses 13pt Medium for name, 12pt Regular `text.muted` for count (right-aligned). 28px row height, `space.xl` horizontal padding.
  - **Active item:** `selection.sidebarBg` fill with `radius.sm` corners (not the default system highlight).
  - **Done section:** Rename the section to "ARCHIVE", add a `border.section` divider above it with `space.lg` spacing.
  - Remove default `Section` styling (system disclosure triangles, etc.) — the sections are always expanded, headers are purely visual.
- **Acceptance Criteria:**
  - Section headers are allcaps with letterspacing, visually lighter than item labels
  - Active sidebar item has a warm accent fill, not system blue
  - "Done" is under an "ARCHIVE" header with a visible divider
  - Sidebar width defaults to 220px
  - Existing tests pass (sidebar accessibility identifiers preserved)
- **Files:** `Sources/PlainApp/PlainApp.swift` (sidebar List, SidebarRow)
- **Tests:** Existing tests pass. `PlainUITests` sidebar interactions still work.

### TASK-011: Rework group headers in task list

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:** Update the `GroupHeader` view (line ~1399 in `PlainApp.swift`):
  - 11pt Bold, allcaps, 1.0pt letterspacing
  - `text.secondary` color
  - Trailing horizontal rule: `border.row` color, extending from after the text to the right edge
  - `space.2xl` (24px) top margin (except first group), `space.md` (8px) bottom margin
- **Acceptance Criteria:**
  - Group headers look like `── PRIORITY A ─────────` with allcaps tracked text and a trailing line
  - Headers are visually distinct from task rows
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (GroupHeader)
- **Tests:** Existing tests pass.

### TASK-012: Restyle the input bar

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005
- **Description:** Update the input bar at the top of the task list:
  - Background: `surface.input` with 1px `border.input` border, `radius.md` corners
  - Height: 44px
  - Left icon: SF Symbol `plus`, `text.muted`, 14pt
  - Placeholder: "Add a task..." in 14pt Regular italic, `text.muted`
  - Right hint: "⌘N" in 11pt `text.muted`, hidden when focused
  - Focus state: border transitions to `border.inputFocused` (system accent at 50%) with `anim.fast`
  - `space.lg` gap below the input bar before the first task row
- **Acceptance Criteria:**
  - Input bar is visually distinct from the task list — reads as a recessed surface
  - Focus ring uses system accent at 50% opacity, not the default system focus ring
  - ⌘N hint disappears on focus
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (input bar area)
- **Tests:** Existing tests pass. Quick-add tests still work.

### TASK-013: Restyle the status bar

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:** Update the status bar at the bottom of the content area:
  - Transparent background (sits on `surface.canvas`)
  - 0.5px `border.row` top border
  - Text: 11pt, `text.muted`
  - Format: "{n} tasks · {n} done this week · {n} overdue"
  - Overdue count >0: `status.overdue` color
  - Height: 28px, vertically centered, `space.xl` horizontal padding
- **Acceptance Criteria:**
  - Status bar has a subtle top border separating it from content
  - Overdue count stands out in red when >0
  - Text uses the warm muted color, not system secondary
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (status bar area)
- **Tests:** Existing tests pass.

---

## Sprint 3 — Interaction Polish (1 week)

**Goal:** Add animations and interaction refinements that make the app feel responsive and considered.

**Dependencies:** Sprint 2 complete.

### TASK-014: Implement completion animation sequence

- **Type:** Implementation
- **Complexity:** High
- **Dependencies:** TASK-004, TASK-009
- **Description:** Implement the choreographed completion sequence from `animation-choreography.md`:
  1. Circle scale pulse 100%→112%→100% (spring, 200ms)
  2. Circle fills with `status.completed` + checkmark fades in
  3. At 400ms: strikethrough wipe left→right (250ms)
  4. At 400ms: row dims to `opacity.completedRow` (200ms)
  5. At 500ms: toast appears
  6. Toast auto-dismisses at 4500ms
  - **Reduced motion:** Skip scale pulse and wipe. Instant fill, strikethrough, dim. Toast without slide.
  - **Undo:** Instant reversal — circle empties, strikethrough removed, opacity restored, toast dismisses.
- **Acceptance Criteria:**
  - Completing a task produces the full visual sequence in order
  - With reduced motion enabled, all changes are instant (except toast appears)
  - Undo reverses cleanly without reverse animation
  - Existing tests pass (undo/redo logic unchanged)
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass. Add a test verifying `accessibilityReduceMotion` disables animations.

### TASK-015: Implement new-task highlight pulse

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-004
- **Description:** When a task is added:
  1. Scroll the list to the new row (animated, 200ms)
  2. Row background pulses: transparent → system accent at 8% → transparent (1s ease-in-out, single cycle)
  3. Row settles to normal appearance
  - **Reduced motion:** Instant scroll, 200ms opacity flash 0.5→1.0
- **Acceptance Criteria:**
  - Adding a task via input bar or quick-add shows the new row with a brief pulse
  - The highlight is accent-colored, not a fixed color
  - Reduced motion substitution works
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass.

### TASK-016: Style search overlay

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005, TASK-004
- **Description:** Restyle the existing search overlay:
  - Floating panel: 400px wide, centered horizontally, 48px below toolbar
  - `surface.input` background, `radius.lg` corners, `shadow.search`
  - Left icon: SF Symbol `magnifyingglass`, `text.muted`
  - Text field: `type.taskBody`, `text.primary`
  - Entrance: fade + slide down 8px (150ms)
  - Exit: fade up (120ms)
  - Non-matching rows fade to `opacity.searchDimmed`
  - Matching text gets `syntax.project` color at 20% opacity highlight with `radius.sm`
- **Acceptance Criteria:**
  - Search overlay floats with a shadow, not inline
  - Non-matching rows dim
  - Matching text is highlighted
  - Animation respects reduced motion
  - Existing search tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (search overlay)
- **Tests:** Existing tests pass.

### TASK-017: Style drag reorder

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-004
- **Description:** Apply the drag styling from the spec:
  - Picked-up row: `shadow.drag`, scale 1.02, `surface.canvas` background
  - Original position: ghost at `opacity.dragPlaceholder`
  - Other rows: spring animation to make space
  - Drop: spring snap to position
- **Acceptance Criteria:**
  - Dragging a row shows elevated shadow and slight scale
  - Other rows animate smoothly to accommodate
  - Drop snaps cleanly
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass.

### TASK-018: Implement hover row menu (··· button)

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-009
- **Description:**
  - On row hover, fade in a "···" icon (SF Symbol `ellipsis`) at the right edge
  - Opacity 0→`opacity.hoverMenu` at `anim.fast`
  - Click opens a standard `NSMenu` with: Complete, Edit, Priority ▸ (A/B/C/None), Move ▸ (Up/Down), Delete
  - Use standard macOS menu styling (not custom)
  - Position: left of due date if present, otherwise at right edge
- **Acceptance Criteria:**
  - ··· icon appears only on hover, fades smoothly
  - NSMenu opens with all specified items
  - Menu actions trigger the correct model mutations
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass. Add tests for menu action routing if practical.

---

## Sprint 4 — Secondary Surfaces (1 week)

**Goal:** Polish all secondary surfaces: onboarding, empty states, conflict banner, toast, and scratch pad.

**Dependencies:** Sprint 2 complete (Sprint 3 can run in parallel for independent tasks).

### TASK-019: Restyle onboarding flow

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005
- **Description:** Update the `PlaceholderCard` / onboarding view:
  - Centered card on `surface.canvas`, `radius.xl` corners
  - Heading: 24pt Semibold — "Point Plain at your todo.txt file."
  - Body: 14pt Regular, `text.secondary`, brief explanation
  - Buttons: "Open an Existing File" (filled, system accent), "Create a New File" (outlined, `border.input`)
  - Tertiary: "Try with a sample file" in `text.muted`, smaller
  - Remove the current SF Symbol icon — the card should feel like an empty desk
  - Generous whitespace
- **Acceptance Criteria:**
  - First launch shows the warm, typographically confident onboarding
  - All three actions work (open, create, sample)
  - Matches the brand doc's "empty desk" vibe
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift` (PlaceholderCard, onboardingView)
- **Tests:** Existing tests pass. `PlainUITests` onboarding flow still works.

### TASK-020: Implement per-filter empty states

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:** Replace the current generic empty state with contextual messages per filter:
  - Inbox: "Nothing here yet. ⌘N to add a task." (⌘N in a subtle pill)
  - Today: "Nothing due today."
  - Overdue: "No overdue tasks — nice."
  - +project: "No tasks in +{project}."
  - @context: "No @{context} tasks."
  - Search: "No tasks match \"{query}\"."
  - Done: "No archived tasks yet."
  - Style: `type.emptyState`, `text.muted`, centered vertically
- **Acceptance Criteria:**
  - Each filter shows its specific message when empty
  - Messages are muted and centered
  - The ⌘N shortcut hint in Inbox is rendered in a subtle pill/background
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass. Consider adding tests for empty state message content per filter.

### TASK-021: Restyle conflict banner

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:** Update the conflict banner:
  - Full-width between input bar and task list
  - Background: `status.conflict` at 10% opacity
  - Left icon: SF Symbol `exclamationmark.triangle.fill` in `status.conflict`
  - Text: "todo.txt changed externally." in `text.primary`, 14pt
  - Right actions: "Reload" | "Keep Mine" | "View Diff" in system accent, 12pt
  - `radius.md` corners, `space.md` padding
- **Acceptance Criteria:**
  - Conflict state shows the styled banner
  - All three actions work
  - Banner uses warm tinted background, not system yellow
  - Existing conflict tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing conflict-handling tests pass.

### TASK-022: Restyle undo toast

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-004, TASK-005
- **Description:** Update the toast notification:
  - Position: bottom center, 16px above status bar
  - Background: `surface.toast` (inverted — dark in light mode, light in dark mode)
  - Text: `text.inverse`, "Task completed · Undo" — "Undo" underlined or in accent color
  - Shadow: `shadow.toast`, `radius.md` corners
  - Animation: `anim.toast.in` (fade + translateY 8px up), linger 4s, `anim.toast.out` (fade + translateY 4px down)
  - Reduced motion: no translate, instant opacity
- **Acceptance Criteria:**
  - Toast appears with the inverted color scheme
  - "Undo" is actionable and visually distinct
  - Auto-dismisses after 4 seconds
  - Reduced motion respected
  - Existing undo tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass.

### TASK-023: Style scratch pad

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005, TASK-006
- **Description:** Update the scratch pad view:
  - Header: "SCRATCH PAD — TODO.TXT" in `type.sidebarSection` (11pt Bold, allcaps, tracked)
  - `surface.input` background
  - Font: SF Mono at `type.scratchPad` size
  - Line numbers: `text.muted`, right-aligned in 36px gutter
  - Syntax highlighting: same token colors as task rows
  - `radius.md` corners, `space.md` inset
  - Crossfade transition (200ms) when toggling
- **Acceptance Criteria:**
  - Scratch pad uses monospace font with line numbers
  - Syntax highlighting is consistent with task rows
  - Toggle transition is smooth
  - Existing tests pass
- **Files:** `Sources/PlainApp/PlainApp.swift`
- **Tests:** Existing tests pass.

---

## Sprint 5 — Quick-Add, Widget, Brand & Final Polish (1 week)

**Goal:** Polish remaining surfaces, apply brand identity, and ensure full visual consistency.

**Dependencies:** Sprints 3 and 4 complete.

### TASK-024: Style quick-add panel

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** TASK-005
- **Description:** Update `QuickAddPanelController.swift`:
  - NSPanel with `NSVisualEffectView` (`.popover` material — this is the one place vibrancy is allowed)
  - Width: 480px
  - No visible text field border — the text field sits directly on the vibrancy surface
  - Entrance: scale 0.98→1.0 + fade (150ms)
  - Exit: fade only (120ms)
  - Reduced motion: instant appearance/disappearance
  - Apply syntax highlighting to the text field content using the same tokens
- **Acceptance Criteria:**
  - Quick-add panel uses system vibrancy, not solid background
  - Text field has no border (borderless style)
  - Animations are smooth and respect reduced motion
  - Existing quick-add tests pass
- **Files:** `Sources/PlainApp/QuickAddPanelController.swift`
- **Tests:** Existing tests pass.

### TASK-025: Apply warm palette to widget

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-001
- **Description:** Update `PlainWidgetBundle.swift` to use the warm token palette:
  - Background: `surface.canvas` equivalents (widget may need hardcoded colors since tokens live in PlainApp target)
  - Text: `text.primary`, `text.muted` equivalents
  - Syntax highlighting if task text is shown
  - Priority badge colors if priorities are displayed
- **Acceptance Criteria:**
  - Widget matches the warm tone of the main app
  - Widget still compiles and renders in widget gallery
- **Files:** `Sources/PlainWidgetExtension/PlainWidgetBundle.swift`
- **Tests:** Existing tests pass.

### TASK-026: Implement about box brand elements

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:**
  - About box: app icon + "plain" wordmark (lowercase, SF Pro Medium) + version + "A todo.txt client for macOS. Reads your file. That's it, really." + copyright
  - Use warm background and text tokens
  - Standard macOS about box position and behavior
- **Acceptance Criteria:**
  - About box shows the branded copy and layout
  - Version string is dynamic
- **Files:** `Sources/PlainApp/PlainAppScenes.swift`
- **Tests:** Compile-only.

### TASK-027: Apply warm palette to Preferences window

- **Type:** Implementation
- **Complexity:** Low
- **Dependencies:** TASK-005
- **Description:** Ensure `PreferencesView` (in `PreferencesStore.swift`) uses `surface.canvas` background and warm text tokens. Standard macOS window chrome — just the warm fill.
- **Acceptance Criteria:**
  - Preferences window matches the warm tone
  - All 4 tabs render correctly
  - Existing tests pass
- **Files:** `Sources/PlainApp/PreferencesStore.swift`
- **Tests:** Existing tests pass.

### TASK-028: Final visual consistency pass

- **Type:** Implementation
- **Complexity:** Medium
- **Dependencies:** All prior tasks
- **Description:** Full-app review against the 6 design documents:
  - Verify every anti-pattern is avoided (no system tint backgrounds, no vibrancy on main surfaces, no rounded row corners, no gradients, no custom window chrome, no centered task text, no sidebar icons)
  - Verify all token references — no remaining hardcoded colors, sizes, or timing values
  - Verify dark mode throughout every surface
  - Verify reduced motion throughout every animation
  - Test at different window sizes (minimum sidebar width, wide windows, tall windows)
  - Verify system accent color works correctly (selection states use system accent, not a fixed color)
  - Check all accessibility identifiers are preserved
- **Acceptance Criteria:**
  - Zero anti-pattern violations
  - No hardcoded visual values remain
  - Dark mode is fully warm and correct
  - Reduced motion produces instant versions of all animations
  - All 123+ tests pass
- **Files:** All PlainApp source files
- **Tests:** Full test suite passes. Manual visual audit documented.

---

## Parallel Execution Groups

These tasks can run simultaneously if multiple engineers are available:

| Group | Tasks | Notes |
|---|---|---|
| Token definition | TASK-001, TASK-002, TASK-003, TASK-004 | TASK-002/003/004 depend on 001 but are independent of each other |
| Sprint 1 visual | TASK-005, TASK-006 | Independent — backgrounds vs. text colors |
| Sprint 2 structure | TASK-010, TASK-011, TASK-012, TASK-013 | All depend on TASK-005 but are independent of each other |
| Sprint 3 + 4 overlap | TASK-015, TASK-016, TASK-019, TASK-020, TASK-021 | Interaction polish and secondary surfaces are independent tracks |
| Sprint 5 surfaces | TASK-024, TASK-025, TASK-026, TASK-027 | All independent peripheral surfaces |

---

## Critical Path

The sequential dependency chain that determines minimum duration:

```
TASK-001 (tokens) 
  → TASK-005 (backgrounds) 
    → TASK-008 (row layout, depends on 006+007) 
      → TASK-009 (row states) 
        → TASK-014 (completion animation) 
          → TASK-028 (final pass)
```

Minimum critical path: ~4 weeks if executed serially with no parallelization.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **SwiftUI `List` fights custom row backgrounds/selection** | High | High | May need to replace `List` with `ScrollView` + `LazyVStack` for full control over row rendering. Spike this in TASK-009 — if `List` can't be tamed, file a follow-up to refactor. |
| **NSMenu integration from SwiftUI hover state** | Medium | Medium | The ··· hover menu (TASK-018) requires bridging to AppKit `NSMenu`. Use `NSViewRepresentable` or `MenuBarExtra`-style approach. Prototype early. |
| **Sidebar section header customization** | Medium | Medium | SwiftUI `Section` headers have limited styling. May need to drop `Section` and use manual `VStack` layout with dividers. Test in TASK-010. |
| **Completion animation timing coordination** | Medium | Low | Multiple sequenced animations (TASK-014) need careful `DispatchQueue`/`Task.sleep` orchestration. Use `withAnimation` chaining and test on both fast and slow machines. |
| **Dark mode token fidelity** | Low | High | If adaptive colors resolve incorrectly, the entire dark mode palette breaks. Mitigate by testing each token in both modes during Sprint 0. |
| **Widget target can't access PlainApp tokens** | Medium | Low | Widget runs in a separate target. May need to duplicate color constants or move tokens to PlainCore. Address in TASK-025. |
| **Existing test fragility** | Low | Medium | Tests may assert on accessibility labels or view hierarchy that changes with the visual refresh. Run the full suite after every task and fix broken assertions immediately. |
| **Performance with syntax-highlighted AttributedStrings** | Low | Medium | Building attributed strings per row on every render could cause scroll jank with large files. Profile in TASK-006; cache if needed. |

---

## Definition of Done — Full Design Refresh

The design refresh is complete when ALL of the following are true:

1. **All 28 tasks are implemented and merged** to `feat/design-refresh`
2. **All existing tests pass** (123+ tests, zero regressions)
3. **Every visual token** from `design-tokens.md` is implemented and referenced (no hardcoded values)
4. **Every component** matches its spec in `component-specs.md` in both light and dark mode
5. **Every animation** from `animation-choreography.md` is implemented with correct timing and reduced-motion fallback
6. **All 8 anti-patterns** from `visual-audit.md` are verified absent
7. **Dark mode** is fully warm (not cool blue-black) across every surface
8. **System accent color** is respected for selection states (not hardcoded)
9. **Accessibility:** reduced motion respected, accessibility identifiers preserved, contrast ratios adequate
10. **Brand:** about box, menu bar icon, onboarding copy, and empty states match `brand-and-icon.md`
11. **Build is clean:** `xcodebuild build` succeeds with zero warnings related to the refresh
12. **README updated** if any setup, build, or architecture changes were introduced

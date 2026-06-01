# Plain — Design Tokens

This document defines every visual value the app uses. All SwiftUI views should reference these tokens, never hardcoded colors or sizes. The token names map to Swift constants (e.g., `Color.plain.textPrimary`, `Spacing.md`).

---

## Color Philosophy

Plain uses a **warm neutral** palette — not the cool blue-grays of default macOS, and not a branded signature color. The warmth is subtle: you wouldn't call the background "cream," but you'd notice it feels less clinical than a stock SwiftUI app. Color enters the interface through two intentional channels: **syntax highlighting** (teal for +projects, violet for @contexts) and **priority coding** (red/amber/blue). Everything else recedes.

Dark mode mirrors the warmth: backgrounds are warm dark grays (brown-tinted, not blue-tinted), not pure black.

---

## Gray Scale (Warm)

These replace the default system grays everywhere in the app. The undertone is warm (slightly yellow-brown), not cool (blue).

| Token | Light | Dark | Usage |
|---|---|---|---|
| `gray.50` | `#FAF9F7` | — | Lightest background tint, hover states |
| `gray.100` | `#F5F3EF` | — | Main content background, sidebar background |
| `gray.150` | `#EDEAE4` | — | Input bar background, card surfaces |
| `gray.200` | `#E3E0D9` | — | Row separators, borders |
| `gray.300` | `#D1CDC4` | — | Disabled states, placeholder shimmer |
| `gray.400` | `#A8A49B` | — | Placeholder text, muted counts |
| `gray.500` | `#858179` | — | Secondary text, key:value metadata |
| `gray.600` | `#6B6760` | — | Sidebar labels, status bar text |
| `gray.700` | `#504D47` | — | Body text alternate |
| `gray.800` | `#3D3B38` | — | Primary heading text |
| `gray.900` | `#2C2A28` | — | Strongest text, window title |

| Token | Dark | Usage |
|---|---|---|
| `grayDark.50` | `#1C1B19` | Deepest background (behind sidebar) |
| `grayDark.100` | `#242320` | Main content background |
| `grayDark.150` | `#2C2A27` | Sidebar background, card surfaces |
| `grayDark.200` | `#383530` | Input bar background |
| `grayDark.300` | `#4A4740` | Row separators, borders |
| `grayDark.400` | `#6B6760` | Disabled states |
| `grayDark.500` | `#858179` | Secondary text |
| `grayDark.600` | `#A8A49B` | Body text |
| `grayDark.700` | `#D1CDC4` | Primary text |
| `grayDark.800` | `#E3E0D9` | Heading text |
| `grayDark.900` | `#F5F3EF` | Strongest text |

---

## Semantic Color Tokens

These are the tokens views actually reference. Each resolves to the appropriate gray-scale value (or accent) depending on light/dark mode.

### Surfaces

| Token | Light | Dark | Usage |
|---|---|---|---|
| `surface.canvas` | `gray.100` (#F5F3EF) | `grayDark.100` (#242320) | Window background, main content area |
| `surface.sidebar` | `gray.50` (#FAF9F7) | `grayDark.50` (#1C1B19) | Sidebar background |
| `surface.input` | `gray.150` (#EDEAE4) | `grayDark.200` (#383530) | Input bar, search field background |
| `surface.hover` | `gray.150` (#EDEAE4) | `grayDark.200` (#383530) | Row hover |
| `surface.selected` | System accent at 12% opacity | System accent at 15% opacity | Row keyboard-selected |
| `surface.toast` | `gray.900` (#2C2A28) | `grayDark.800` (#E3E0D9) | Undo toast background (inverted) |
| `surface.quickAdd` | NSVisualEffectView `.popover` | NSVisualEffectView `.popover` | Quick-add panel, uses system vibrancy |

### Text

| Token | Light | Dark | Usage |
|---|---|---|---|
| `text.primary` | `gray.900` (#2C2A28) | `grayDark.800` (#E3E0D9) | Task body text, headings |
| `text.secondary` | `gray.600` (#6B6760) | `grayDark.500` (#858179) | Sidebar labels, group headers |
| `text.muted` | `gray.400` (#A8A49B) | `grayDark.400` (#6B6760) | Counts, dates, status bar, placeholders |
| `text.inverse` | `gray.50` (#FAF9F7) | `grayDark.100` (#242320) | Text on toast background |

### Borders & Separators

| Token | Light | Dark | Usage |
|---|---|---|---|
| `border.row` | `gray.200` (#E3E0D9) | `grayDark.300` (#4A4740) | Task row bottom separator |
| `border.section` | `gray.300` (#D1CDC4) | `grayDark.300` (#4A4740) | Sidebar section dividers |
| `border.input` | `gray.200` (#E3E0D9) | `grayDark.300` (#4A4740) | Input bar border (unfocused) |
| `border.inputFocused` | System accent at 50% | System accent at 50% | Input bar border (focused) |

### Selection & Focus

| Token | Light | Dark | Usage |
|---|---|---|---|
| `selection.bar` | System accent | System accent | 2px left-edge bar on focused row |
| `selection.bg` | System accent at 10% | System accent at 15% | Focused row background fill |
| `selection.sidebarBg` | System accent at 12% | System accent at 18% | Active sidebar filter row |

---

## Syntax Highlighting Palette

These are the brand-adjacent colors — the most distinctive visual element of the app. They should be muted enough to scan without becoming distracting. Think well-configured IDE, not children's toy.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `syntax.project` | `#3A8A7A` | `#5BB8A6` | `+project` tags — warm teal |
| `syntax.context` | `#7B5EA7` | `#A98BD4` | `@context` tags — muted violet |
| `syntax.keyValue` | `gray.500` (#858179) | `grayDark.500` (#858179) | `key:value` pairs — neutral, quieter than body |
| `syntax.date` | `gray.500` (#858179) | `grayDark.500` (#858179) | Creation dates in row — same as keyValue |

### Priority Colors

Used for the priority badge text and the completion circle tint on prioritized tasks.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `priority.A` | `#C4432A` | `#E8715C` | Priority (A) — warm red |
| `priority.B` | `#B8860B` | `#DAA832` | Priority (B) — dark amber/gold |
| `priority.C` | `#4A7FB5` | `#6FA8DC` | Priority (C) — slate blue |
| `priority.low` | `gray.400` (#A8A49B) | `grayDark.400` (#6B6760) | Priority (D)+ — muted |

### Priority Badge Backgrounds

Subtle tinted backgrounds behind priority badges in task rows. Very low opacity — just enough to read the letter as a "badge" rather than floating text.

| Token | Light | Dark |
|---|---|---|
| `priority.A.bg` | `#C4432A` at 10% | `#E8715C` at 12% |
| `priority.B.bg` | `#B8860B` at 10% | `#DAA832` at 12% |
| `priority.C.bg` | `#4A7FB5` at 10% | `#6FA8DC` at 12% |
| `priority.low.bg` | `gray.300` at 40% | `grayDark.300` at 40% |

---

## Status & Feedback Colors

| Token | Light | Dark | Usage |
|---|---|---|---|
| `status.overdue` | `#C4432A` | `#E8715C` | "Overdue" label, overdue count in sidebar |
| `status.today` | `#3A8A7A` | `#5BB8A6` | "Today" and "due today" accents |
| `status.completed` | `gray.400` (#A8A49B) | `grayDark.400` (#6B6760) | Completed row text + checkbox fill |
| `status.conflict` | `#B8860B` | `#DAA832` | Conflict banner background tint (at 15%) |
| `status.success` | `#3A8A7A` | `#5BB8A6` | Transient success feedback |
| `status.destructive` | `#C4432A` | `#E8715C` | Delete confirmation |

---

## Typography

Plain uses system fonts exclusively — SF Pro for the UI, SF Mono for scratch pad. This is intentional: it's the fastest-rendering choice, it respects the user's system-level accessibility settings, and it signals "I'm a native app, not an Electron wrapper."

Personality comes from **weight contrast** and **size hierarchy**, not font choice.

### Type Scale

| Token | Size | Weight | Tracking | Usage |
|---|---|---|---|---|
| `type.windowTitle` | 13pt | Semibold | 0 | Filename in toolbar |
| `type.sidebarSection` | 11pt | Bold (allcaps) | 1.2pt | "SMART FILTERS", "+PROJECTS", "@CONTEXTS" |
| `type.sidebarLabel` | 13pt | Medium | 0 | Filter names in sidebar |
| `type.sidebarCount` | 12pt | Regular | 0 | Task counts in sidebar |
| `type.groupHeader` | 11pt | Bold (allcaps) | 1.0pt | Group section headers ("PRIORITY A", "NO DATE") |
| `type.taskBody` | 14pt | Regular | 0 | Primary task text |
| `type.taskTags` | 14pt | Medium | 0 | +project and @context within task text |
| `type.taskMeta` | 12pt | Regular | 0 | key:value pairs, creation dates within rows |
| `type.taskDueDate` | 12pt | Medium | 0 | Right-aligned due date label |
| `type.priorityBadge` | 12pt | Semibold | 0 | "(A)" badge text |
| `type.inputBar` | 14pt | Regular | 0 | Add-task text field |
| `type.inputPlaceholder` | 14pt | Regular (italic) | 0 | "Add a task..." placeholder |
| `type.inputHint` | 11pt | Regular | 0 | "⌘N" shortcut hint |
| `type.statusBar` | 11pt | Regular | 0 | "15 tasks · 0 done this week · 0 overdue" |
| `type.scratchPad` | 13pt | Regular (SF Mono) | 0 | Raw file editor |
| `type.toastMessage` | 12pt | Medium | 0 | "Task completed · Undo" |
| `type.emptyState` | 14pt | Regular | 0 | "No @errands — nice." |
| `type.onboardingHeading` | 24pt | Semibold | -0.3pt | "Point Plain at your todo.txt file." |
| `type.onboardingBody` | 14pt | Regular | 0 | Onboarding explanatory text |

### Type Rules

- Sidebar section headers ("SMART FILTERS") are set in allcaps with tracked-out letterspacing. This gives the sidebar structure without needing visual weight or divider lines between every section.
- Group headers in the task list follow the same allcaps pattern.
- Task body text is 14pt — one point larger than the macOS default 13pt. This small bump gives the task list breathing room and makes scanning faster.
- The user-configurable font size slider (11pt–18pt) scales `type.taskBody`, `type.taskTags`, `type.inputBar`, and `type.emptyState` proportionally. Other tokens (sidebar, status bar, badges) stay fixed.

---

## Spacing Scale

All spacing values use a 4px base unit. Reference by token name, not raw number.

| Token | Value | Usage |
|---|---|---|
| `space.xs` | 2px | Inline gaps (badge text padding, icon-to-label within a badge) |
| `space.sm` | 4px | Tight internal spacing (between priority badge and task text) |
| `space.md` | 8px | Standard internal padding (row content padding top/bottom) |
| `space.lg` | 12px | Component gaps (between input bar and first row, between sections) |
| `space.xl` | 16px | Row horizontal padding, sidebar item horizontal padding |
| `space.2xl` | 24px | Section spacing (between sidebar sections, between group header and first row) |
| `space.3xl` | 32px | Major structural gaps (toolbar to content, onboarding layout) |

### Key Measurements

| Element | Value |
|---|---|
| Sidebar width (default) | 220px |
| Sidebar width (min) | 180px |
| Sidebar width (max) | 300px |
| Task row height (min) | 40px |
| Task row height (with metadata line) | 52px |
| Input bar height | 44px |
| Status bar height | 28px |
| Toolbar height | Standard macOS toolbar |
| Completion circle diameter | 18px |
| Priority badge height | 20px |
| Priority badge corner radius | 4px |
| Selection bar width (left edge) | 3px |
| Group header height | 28px |
| Sidebar item height | 28px |
| Row separator thickness | 0.5px |
| Toast corner radius | 8px |
| Search overlay corner radius | 10px |
| Search overlay width | 400px |

---

## Shadows

Shadows are used sparingly — only on floating/overlay surfaces, never on flat content.

| Token | Value (Light) | Value (Dark) | Usage |
|---|---|---|---|
| `shadow.toast` | 0 2px 8px rgba(44,42,40, 0.12) | 0 2px 8px rgba(0,0,0, 0.3) | Undo toast |
| `shadow.search` | 0 4px 20px rgba(44,42,40, 0.15) | 0 4px 20px rgba(0,0,0, 0.4) | Cmd+F search overlay |
| `shadow.quickAdd` | 0 8px 32px rgba(44,42,40, 0.2) | 0 8px 32px rgba(0,0,0, 0.5) | Global quick-add panel |
| `shadow.drag` | 0 4px 12px rgba(44,42,40, 0.15) | 0 4px 12px rgba(0,0,0, 0.35) | Row being dragged |
| `shadow.menuRow` | none | none | Hover menu "···" — no shadow, just opacity |

---

## Corner Radii

| Token | Value | Usage |
|---|---|---|
| `radius.none` | 0 | Task rows, sidebar items (sharp edges, list-native) |
| `radius.sm` | 4px | Priority badge, tag pills, search match highlight |
| `radius.md` | 8px | Toast, input bar, conflict banner |
| `radius.lg` | 10px | Search overlay, quick-add panel |
| `radius.xl` | 12px | Onboarding card, preferences pane |

---

## Animation Tokens

All timings and curves are defined here. Views reference the token, not raw values.

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `anim.fast` | 120ms | ease-out | Hover state transitions, badge color changes |
| `anim.normal` | 200ms | ease-in-out | Sidebar collapse, scratch pad toggle, filter change crossfade |
| `anim.slow` | 300ms | ease-in-out | Task completion sequence, row deletion collapse |
| `anim.pulse` | 1000ms | ease-in-out (auto-reverse) | New-task highlight pulse, then settles |
| `anim.spring` | response: 0.35, dampingFraction: 0.7 | SwiftUI spring | Row reorder snap, drag release |
| `anim.toast.in` | 200ms | ease-out | Toast appear (fade + translate Y 8px) |
| `anim.toast.out` | 150ms | ease-in | Toast dismiss |
| `anim.toast.linger` | 4000ms | — | Toast auto-dismiss delay |
| `anim.searchIn` | 150ms | ease-out | Search overlay appear (fade + translate Y -8px) |
| `anim.searchOut` | 120ms | ease-in | Search overlay dismiss |
| `anim.quickAdd.in` | 150ms | ease-out | Quick-add panel appear (fade + scale 0.98→1.0) |
| `anim.quickAdd.out` | 120ms | ease-in | Quick-add panel dismiss |
| `anim.completion.delay` | 400ms | — | Pause before strikethrough starts (allows undo) |
| `anim.completion.circle` | 200ms | spring (damping 0.6) | Circle fill with brief overshoot |
| `anim.completion.strike` | 250ms | ease-in-out | Left-to-right strikethrough wipe |
| `anim.completion.dim` | 200ms | ease-out | Row opacity transition to 0.45 |

### Reduced Motion

When `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true, all animated transitions become instant (duration: 0). The new-task highlight pulse uses an opacity flash instead of a scaling pulse. The completion sequence skips the strikethrough wipe and immediately applies the completed visual state.

---

## Opacity Tokens

| Token | Value | Usage |
|---|---|---|
| `opacity.completedRow` | 0.45 | Completed task row (text, badge, date) |
| `opacity.hoverMenu` | 0.0 → 0.7 | "···" menu icon on hover |
| `opacity.disabledControl` | 0.4 | Disabled buttons/controls |
| `opacity.dragPlaceholder` | 0.3 | Ghost row left behind during drag |
| `opacity.searchDimmed` | 0.35 | Non-matching rows during active search |

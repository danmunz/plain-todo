# Plain — Visual Audit & Revamp Priorities

This document compares the current app state to the target design, identifies every gap, and prioritizes them so the agent knows what to change and in what order. Reference `design-tokens.md` for all concrete values.

---

## Current State Summary

The app currently looks like a default SwiftUI `NavigationSplitView` with minimal customization. It is functional but visually undifferentiated — there is no sense of brand, warmth, or considered design. Specific observations from the current screenshot:

1. **Backgrounds are stock macOS gray.** The sidebar and content area use the default system `List` background. No warmth, no intentional color.
2. **The "Plain" heading and subtitle are rendered as inline content.** The app name and file status string sit inside the scrollable content area, taking up vertical space that should belong to the toolbar or window title. This is a layout anti-pattern — it makes the app look like a web page, not a native tool.
3. **Task rows are double-line and redundant.** Each row shows the task text on line 1 and then *the exact same text* on line 2 in a lighter style. There is no visual parsing — no syntax highlighting, no priority badges, no tag colors, no due date treatment.
4. **The completion circle is a stock SwiftUI circle.** No weight, no fill transition, no personality.
5. **The input bar has a generic "Add a task..." placeholder** with a badge-like "⌘N" pill. The bar itself blends into the background with no visual differentiation.
6. **The sidebar uses default list styling.** Smart filters, project/context sections, and the Done item all use the same visual weight. There are no section headers ("SMART FILTERS", "+PROJECTS") — just a flat list. The count badges are plain numbers.
7. **The group header ("No Date") is a plain text label.** No allcaps, no letterspacing, no visual weight to separate it from task content.
8. **The status bar ("15 tasks · 0 done this week · 0 overdue") is present** but visually indistinct from the content above it.
9. **No row interaction states are visible.** The selected row (blue highlight, "Blurb for Brian...") uses the stock system selection style — full-width blue fill. There is no left-edge accent bar, no warm tint.
10. **The sort picker ("Creation Date") in the toolbar is functional** but generic.
11. **No syntax highlighting anywhere.** +project, @context, key:value, and dates are all rendered in the same default text style.
12. **Row separators are absent or barely visible** — the rows run together without clear delineation.
13. **The window title ("todo_2026.txt") and toolbar icons are functional** but the toolbar feels sparse and lacks visual cohesion.

---

## Target State

The app should feel like iA Writer meets Things 3 — warm, typographically confident, quiet but not bland. Specific targets:

- A warm off-white canvas that makes the window feel considered, not default.
- Syntax highlighting that makes scanning task lists effortless.
- Priority badges with color-coded tinted backgrounds that read as meaningful at a glance.
- Allcaps tracked-out section headers that give the sidebar and group headers visual structure.
- An input bar that feels like a distinct, inviting surface — slightly recessed or differentiated.
- Task rows with single-line density, clear anatomy (circle → badge → text → due date), and hover/selection states that use the warm palette.
- Breathing room — the current layout is tight in a "default" way, not a "considered density" way.

---

## Revamp Priority Tiers

### Tier 1: Foundational (do these first — they change the whole feel)

These are the changes that will make the biggest difference with the least risk. Do all of Tier 1 before moving to Tier 2.

#### 1.1 Replace all backgrounds with warm palette

- **Window background** → `surface.canvas` (warm off-white, not system gray)
- **Sidebar background** → `surface.sidebar` (slightly lighter warm)
- **Input bar** → `surface.input` with `border.input` border
- Remove any `.listStyle(.sidebar)` or `.listStyle(.insetGrouped)` that forces system background colors. Use explicit background fills from the token palette.
- In dark mode, these map to the `grayDark.*` equivalents — warm dark grays, not system dark.

**How to verify:** The window should no longer look like a default macOS app. It should read as subtly warmer than Finder, Notes, or Reminders. Side-by-side with a stock SwiftUI window, the difference should be perceptible but not jarring.

#### 1.2 Implement syntax highlighting in task rows

This is the single most impactful visual change. Every task row should parse its text and apply token-based coloring:

- `+project` segments → `syntax.project` color, `type.taskTags` weight (Medium)
- `@context` segments → `syntax.context` color, `type.taskTags` weight (Medium)
- `key:value` segments → `syntax.keyValue` color, `type.taskMeta` size (12pt)
- Plain text → `text.primary`, `type.taskBody` weight (Regular)
- Completed rows → all text at `opacity.completedRow` with strikethrough

The highlighting should work in both the task list and the inline edit field.

**How to verify:** Looking at a task like `(A) Call accountant @phone +taxes due:2026-05-29`, you should be able to instantly distinguish the priority, the context, the project, and the metadata by color alone without reading the punctuation characters.

#### 1.3 Add priority badges

Replace the current plain-text priority display with color-coded badges:

- Render `(A)`, `(B)`, etc. as a compact badge: the letter inside a rounded rect with `priority.*.bg` background tint and `priority.*` text color.
- Size: `type.priorityBadge` (12pt Semibold), `radius.sm` corner radius, height `20px`.
- For unprioritized tasks, no badge — the space collapses so there's no empty gap.
- The badge sits between the completion circle and the task text.

**How to verify:** Priority A tasks should have a subtle warm-red pill; priority C tasks a subtle blue pill. The badges should be scannable without reading — color alone conveys urgency tier.

#### 1.4 Fix task row layout and remove the duplicate line

The current double-line row (rendered text + raw text) must become a single structured row:

```
[ ○ ] [ (A) ] Call accountant @phone +taxes              [ May 29 ]
```

Left to right:
1. Completion circle (18px diameter, 1.5px stroke, `text.muted` color)
2. Priority badge (if present, else collapse)
3. Task text with inline syntax highlighting (fills available width)
4. Due date label, right-aligned (`type.taskDueDate`, `text.muted` — or `status.overdue` if past due, or `status.today` if due today)

Row height: `40px` minimum, expanding only if the user's font size preference forces wrapping.

Remove the secondary subtitle line entirely. The task text *is* the rendered content — no "raw line" echo.

#### 1.5 Implement row interaction states

- **Hover:** `surface.hover` background, fade in at `anim.fast` speed. A "···" menu icon (`opacity.hoverMenu`) fades in at the right edge.
- **Selected (keyboard):** `selection.bg` fill + `selection.bar` (3px accent-colored left edge). No full-width system blue highlight.
- **Row separator:** 0.5px `border.row` line at the bottom of each row. Subtle but present — it separates rows without creating a "grid" feel.

---

### Tier 2: Structure & Hierarchy (do after Tier 1 is solid)

#### 2.1 Rework sidebar hierarchy

The sidebar needs three distinct visual tiers:

**Section headers** ("SMART FILTERS", "+PROJECTS", "@CONTEXTS", "ARCHIVE"):
- `type.sidebarSection` — 11pt Bold, allcaps, 1.2pt letterspacing
- `text.muted` color
- 16px left padding, 8px bottom margin before first item
- No background, no interaction — pure label

**Sidebar items** (Inbox, Today, @work, +shipping, etc.):
- `type.sidebarLabel` (13pt Medium) for the name
- `type.sidebarCount` (12pt Regular, `text.muted`) for the count, right-aligned
- `space.xl` horizontal padding, `28px` row height
- Active item: `selection.sidebarBg` fill with `radius.sm` corner radius
- Hover: `surface.hover` fill

**Done section:**
- Separated from `@contexts` by a `border.section` divider with `space.lg` spacing above and below
- Under its own "ARCHIVE" section header
- Same item styling as other sidebar items

#### 2.2 Rework group headers in task list

Replace the current plain-text group labels with the allcaps tracked style:

- `type.groupHeader` — 11pt Bold, allcaps, 1.0pt letterspacing
- `text.secondary` color
- A thin `border.row` line extending from after the text to the right edge
- `space.2xl` top margin (except for the first group), `space.md` bottom margin

Pattern: `── PRIORITY A ──────────────────────`

The line after the text is a visual anchor — it makes the group header feel structural rather than floating.

#### 2.3 Restyle the input bar

The input bar should be visually distinct from the task list — a surface you're drawn to:

- Background: `surface.input` with 1px `border.input` border and `radius.md` corners
- Height: 44px
- A `+` icon (SF Symbol `plus`, `text.muted`, 14pt) at the left edge
- Placeholder: "Add a task..." in `type.inputPlaceholder` (14pt Regular italic, `text.muted`)
- `⌘N` hint at the right edge in `type.inputHint` (11pt, `text.muted`), hidden when focused
- On focus: border transitions to `border.inputFocused` (system accent at 50%)
- `space.lg` gap between input bar bottom and first task row

#### 2.4 Restyle the status bar

- Background: none (transparent, sits on canvas)
- Text: `type.statusBar` (11pt), `text.muted`
- Top border: 0.5px `border.row` line
- Content: "15 tasks · 3 done this week · 0 overdue"
- The "overdue" count, if >0, uses `status.overdue` color
- Height: 28px, vertically centered text
- `space.xl` horizontal padding

---

### Tier 3: Interaction Polish (do after Tier 2 is solid)

#### 3.1 Completion animation

When a task is completed:
1. After `anim.completion.delay` (400ms), the circle fill animates with `anim.completion.circle` (spring with overshoot)
2. Circle fills with `status.completed` color
3. Text receives a left-to-right strikethrough wipe at `anim.completion.strike` speed
4. Entire row dims to `opacity.completedRow` at `anim.completion.dim` speed
5. A toast appears at the bottom: "Task completed · Undo" with `surface.toast` background, `text.inverse` text, `shadow.toast`, `radius.md` corners
6. Toast auto-dismisses after `anim.toast.linger` (4s)
7. All animations respect reduced-motion (instant if accessibility flag is set)

#### 3.2 New-task highlight pulse

When a task is added:
1. List scrolls to the new row
2. Row background pulses with system accent at 8% opacity, using `anim.pulse` (1s ease-in-out auto-reverse)
3. After the pulse completes, the row settles to normal `surface.canvas` background
4. Under reduced-motion: a brief 200ms opacity flash from 0.5 to 1.0 instead

#### 3.3 Search overlay styling

- Floating panel, centered horizontally, 48px below the toolbar
- Width: 400px, `radius.lg` corners, `shadow.search`
- Background: `surface.input` (not vibrancy — this is an in-app overlay, not system-level)
- 🔍 icon at left (SF Symbol `magnifyingglass`, `text.muted`)
- Text field: `type.taskBody`, `text.primary`
- Appear: `anim.searchIn` (fade + slide down 8px)
- Dismiss: `anim.searchOut`
- When active, non-matching rows fade to `opacity.searchDimmed`
- Matching text within surviving rows gets a highlight: `syntax.project` color at 20% opacity background with `radius.sm`

#### 3.4 Drag reorder styling

- Picked-up row: `shadow.drag`, slight scale (1.02), background becomes `surface.canvas` (not transparent)
- Original position: ghost row at `opacity.dragPlaceholder`
- Other rows animate with `anim.spring` to make space
- Drop: row snaps to position with `anim.spring`

#### 3.5 Hover row menu

- On hover, a "···" icon (SF Symbol `ellipsis`) fades in at the right edge of the row
- Opacity: 0 → `opacity.hoverMenu` at `anim.fast`
- Positioned to the left of the due date (if present) or at the right edge
- Click opens a standard NSMenu with: Complete, Edit, Priority ▸ (A/B/C/None), Move ▸ (Up/Down), Delete
- The menu items use standard macOS menu styling (not custom)

---

### Tier 4: Secondary Surfaces (do last)

#### 4.1 Onboarding flow

- Centered card on `surface.canvas` background, `radius.xl` corners
- Heading: `type.onboardingHeading` — "Point Plain at your todo.txt file."
- Body: `type.onboardingBody`, `text.secondary`
- Two buttons: "Open an Existing File" (filled, system accent) and "Create a New File" (outlined, `border.input` border)
- A third option, smaller: "Try with a sample file" in `text.muted`
- The onboarding should feel like an empty desk — warm, clean, inviting. Lots of whitespace.

#### 4.2 Empty states

Per-filter contextual messages using `type.emptyState`, `text.muted`, centered vertically in the content area:

| Filter | Message |
|---|---|
| Inbox (no tasks) | Nothing here yet. ⌘N to add a task. |
| Today (none due) | Nothing due today. |
| Overdue (none) | No overdue tasks — nice. |
| +project (empty) | No tasks in +{project}. |
| @context (empty) | No @{context} tasks. |
| Search (no match) | No tasks match "{query}". |
| Done (no archive) | No archived tasks yet. |

These are quiet, not cute. One line, centered, muted. The humor is deployed in the *absence* of copy, not in forced jokes.

#### 4.3 Conflict banner

- Full-width banner between the input bar and the task list
- Background: `status.conflict` at 10% opacity
- Left icon: SF Symbol `exclamationmark.triangle.fill` in `status.conflict` color
- Text: "todo.txt changed externally." in `text.primary`, `type.taskBody`
- Three action links at the right: "Reload" | "Keep Mine" | "View Diff" in system accent, `type.taskMeta` size
- `radius.md` corners, `space.md` vertical padding

#### 4.4 Undo toast

- Fixed to bottom center of the content area, 16px above the status bar
- Background: `surface.toast`, `shadow.toast`, `radius.md`
- Text: "Task completed · Undo" — the "Undo" portion is underlined or uses system accent color
- `type.toastMessage`, `text.inverse`
- Appears with `anim.toast.in`, auto-dismisses after `anim.toast.linger` with `anim.toast.out`

#### 4.5 Scratch pad styling

- Replaces the task list in the main content area (input bar and status bar remain)
- A small header: "Scratch Pad — todo.txt" in `type.sidebarSection` style (allcaps, tracked)
- `surface.input` background
- SF Mono at `type.scratchPad` size
- Line numbers in `text.muted`, right-aligned in a 36px gutter
- Syntax highlighting active on the raw text (same token colors as the task list)
- `radius.md` corners on the editor area, `space.md` inset

---

## Anti-Patterns to Avoid

These are things the agent should explicitly NOT do:

1. **Do not use system `.tint` or `.accentColor` as a background fill.** The system accent is for interactive elements (focus rings, active filters, buttons) not surfaces. Surfaces use the warm gray palette.
2. **Do not use vibrancy/material effects on the sidebar or content area.** Vibrancy is reserved for transient floating panels (quick-add). The main window uses solid warm fills.
3. **Do not add rounded corners to task rows.** Rows are flat list items — they have separators, not card borders. Rounding them turns the list into a stack of cards, which is the wrong spatial metaphor.
4. **Do not use colored backgrounds on task rows** (except the hover and selection states). The row background is always `surface.canvas` in its default state. Color lives in the text (syntax highlighting) and the priority badge, not the row fill.
5. **Do not add iconography to sidebar filter items.** No emoji, no SF Symbol icons next to "Inbox", "Today", etc. The sidebar is text-only. Counts are the only secondary element.
6. **Do not use gradients anywhere in the app.** Plain's aesthetic is flat and warm, not dimensional.
7. **Do not override the macOS window chrome** (title bar, traffic lights). Use the standard `.toolbar` content area. The app should feel native, not frameless.
8. **Do not center task text.** All task content is left-aligned. The only centered elements in the entire app are onboarding content and empty states.

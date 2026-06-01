# Plain — Component Specs

Detailed visual specification for each UI component. Reference `design-tokens.md` for all color, type, spacing, and animation values. Reference `visual-audit.md` for implementation priority ordering.

---

## 1. Task Row

The task row is the most important component in the app. It appears hundreds of times on screen and must be scannable, information-dense without clutter, and instantly interactive.

### Layout

```
├─ space.xl (16px) left padding
├─ Completion Circle (18px × 18px)
├─ space.sm (4px) gap
├─ Priority Badge (if present, else collapse this + the gap)
├─ space.sm (4px) gap
├─ Task Text (fills remaining width, with inline syntax highlighting)
├─ flexible space
├─ Due Date Label (right-aligned, only if due: exists)
├─ space.sm (4px) gap
├─ Hover Menu "···" (only on hover, overlaps due date area if no date)
├─ space.xl (16px) right padding
```

Row minimum height: 40px (vertically centered content). If the task text wraps at the user's chosen font size, the row expands to fit.

### Completion Circle

- Default: 18px diameter, 1.5px stroke, `text.muted` color, transparent fill
- Hover (circle only): stroke color transitions to `text.secondary` at `anim.fast`
- Prioritized tasks: stroke color matches the priority color (`priority.A`, `.B`, `.C`, or `.low`) instead of `text.muted`
- Completed: filled with `status.completed` color, with a small checkmark (SF Symbol `checkmark`, 10pt, `text.inverse`) centered inside
- Transition: see `animation-choreography.md` for the completion sequence

### Priority Badge

- Visible only for prioritized tasks. If no priority, this element and its trailing gap collapse to zero width.
- Shape: rounded rect, height 20px, horizontal padding `space.sm` (4px) on each side, `radius.sm` (4px) corners
- Background: `priority.*.bg` (the priority color at 10–12% opacity)
- Text: the letter only (not the parens) — "A", "B", "C", etc. — in `type.priorityBadge` (12pt Semibold), colored with `priority.*`
- Completed rows: badge stays visible but at `opacity.completedRow`

### Task Text

- Font: `type.taskBody` (14pt Regular)
- Color: `text.primary`
- Inline syntax highlighting applied as attributed string segments:
  - `+project` → `syntax.project` color, `type.taskTags` weight (Medium)
  - `@context` → `syntax.context` color, `type.taskTags` weight (Medium)
  - `key:value` → `syntax.keyValue` color, `type.taskMeta` size (12pt Regular). Rendered inline, not pulled out of the text.
  - `due:YYYY-MM-DD` → hidden from inline text (extracted to the right-aligned due date label instead)
  - Creation dates (the date immediately after the priority or at line start) → `syntax.date` color, `type.taskMeta` size
  - Everything else → `text.primary`, `type.taskBody`

- Completed rows: entire text at `opacity.completedRow` with a 0.5px strikethrough line in `text.muted`
- Text is single-line by default, truncating with `…` if it exceeds available width. If the user's font size preference causes common tasks to truncate, allow wrapping to a second line.

### Due Date Label

- Visible only when a `due:` value is present in the task
- Position: right-aligned within the row, before the right padding
- Font: `type.taskDueDate` (12pt Medium)
- Format: humanized relative label — "Today", "Tomorrow", "Jun 5", "Overdue"
- Color:
  - Past due → `status.overdue`
  - Due today → `status.today`
  - Future → `text.muted`
- Completed rows: `text.muted` at `opacity.completedRow`, no special overdue coloring

### Row States

| State | Background | Left Edge | Other |
|---|---|---|---|
| Default | `surface.canvas` (transparent) | none | — |
| Hover | `surface.hover` | none | "···" menu fades in at right |
| Selected (keyboard) | `selection.bg` | 3px `selection.bar` | — |
| Selected + Hover | `selection.bg` | 3px `selection.bar` | "···" menu visible |
| Editing | `surface.canvas` | 3px system accent | Text becomes editable text field |
| Completed | `surface.canvas` | none | All content at `opacity.completedRow`, strikethrough |
| Dragging | `surface.canvas` + `shadow.drag` | none | Slight scale (1.02), lifted above other rows |
| Drag placeholder | `surface.canvas` at `opacity.dragPlaceholder` | none | Ghost of original position |
| Multi-selected | `selection.bg` at 60% | 3px `selection.bar` | Multiple rows highlighted |

### Row Separator

- 0.5px line at the bottom of each row
- Color: `border.row`
- Inset: starts at the left edge of the task text (after circle + badge), extends to right edge of row. Does NOT extend under the completion circle — this groups the circle visually with its row.

---

## 2. Sidebar

### Overall

- Width: 220px default, resizable 180–300px, collapsible with `Cmd+\`
- Background: `surface.sidebar`
- No vibrancy, no transparency — solid warm fill
- Right edge: 0.5px `border.section` separator between sidebar and content area

### Section Structure (top to bottom)

1. **Smart Filters section**
   - Header: "SMART FILTERS" in `type.sidebarSection`
   - Items: Inbox, Today, Overdue
   - Overdue count uses `status.overdue` color when > 0

2. **+Projects section**
   - Header: "+PROJECTS" in `type.sidebarSection`
   - Items: alphabetically sorted discovered +project tags
   - Each shows the tag name (without the `+` prefix) and a count

3. **@Contexts section**
   - Header: "@CONTEXTS" in `type.sidebarSection`
   - Items: alphabetically sorted discovered @context tags
   - Each shows the tag name (without the `@` prefix) and a count

4. **Archive section** (below a `border.section` divider)
   - Header: "ARCHIVE" in `type.sidebarSection`
   - Item: "Done" with count of tasks in `done.txt`

### Section Header

- Text: `type.sidebarSection` (11pt Bold, allcaps, 1.2pt letterspacing)
- Color: `text.muted`
- Left padding: `space.xl` (16px)
- Top margin: `space.2xl` (24px) — except the first section, which uses `space.lg` (12px)
- Bottom margin: `space.sm` (4px)
- Not interactive, no hover state

### Sidebar Item

- Height: 28px, vertically centered
- Left padding: `space.xl` (16px)
- Right padding: `space.xl` (16px)
- Label: `type.sidebarLabel` (13pt Medium), `text.primary` color
- Count: `type.sidebarCount` (12pt Regular), `text.muted`, right-aligned
- Corner radius: `radius.sm` (4px) — applied as inset from the sidebar edges by 6px horizontal (so the highlight doesn't touch the sidebar walls)

| State | Background | Text Color |
|---|---|---|
| Default | transparent | `text.primary` (label), `text.muted` (count) |
| Hover | `surface.hover` | unchanged |
| Active (selected filter) | `selection.sidebarBg` | `text.primary` (label), `text.primary` (count) |

### Section Divider (before Archive)

- 0.5px `border.section` line
- Full sidebar width minus `space.xl` padding on each side
- `space.lg` (12px) vertical margin above and below

---

## 3. Input Bar

### Layout

```
┌─ radius.md rounded container ──────────────────────────────────────┐
│  space.xl │ + icon │ space.sm │ text field │ flexible │ ⌘N │ space.xl │
└────────────────────────────────────────────────────────────────────┘
```

- Background: `surface.input`
- Border: 1px `border.input`
- Corner radius: `radius.md` (8px)
- Height: 44px
- Horizontal margin: `space.xl` (16px) from content area edges (so it doesn't touch the sidebar divider or window edge)
- Bottom margin: `space.lg` (12px) to first task row

### Elements

- **+ icon:** SF Symbol `plus`, 14pt, `text.muted`
- **Text field:** `type.inputBar` (14pt Regular), `text.primary`
- **Placeholder:** "Add a task..." in `type.inputPlaceholder` (14pt Regular italic, `text.muted`)
- **Shortcut hint:** "⌘N" in `type.inputHint` (11pt Regular, `text.muted`), right-aligned

### States

| State | Border | Hint | Other |
|---|---|---|---|
| Unfocused | `border.input` | "⌘N" visible | Entire bar is click target |
| Focused | `border.inputFocused` (accent at 50%) | hidden | + icon stays, cursor appears |
| Focused + typing | `border.inputFocused` | hidden | Live date preview may appear below |
| Focused + date detected | `border.inputFocused` | hidden | Preview tooltip below the bar |

### Date Preview Tooltip

- Appears only when the date parser detects a date expression in the input
- Position: below the input bar, left-aligned with the text field start
- Background: `surface.hover`, `radius.sm`, `shadow.toast`
- Text: "→ " followed by the parsed todo.txt line with syntax highlighting applied
- Font: `type.taskMeta` (12pt)
- Disappears when the date expression is removed or on commit

---

## 4. Toolbar

### Content (left to right)

1. **Sidebar toggle** — SF Symbol `sidebar.leading`, standard toolbar button
2. **Window title** — current filename ("todo_2026.txt") in `type.windowTitle` (13pt Semibold), centered in the toolbar area. Uses the standard macOS toolbar title position.
3. **Sort picker** — dropdown showing current sort mode ("Priority ▾"), standard toolbar button style. Options: Priority, Creation Date, Due Date, Alphabetical, File Order.
4. **Scratch pad toggle** — SF Symbol `doc.plaintext`, standard toolbar button. Active state: filled variant of the icon.
5. **Archive button** — SF Symbol `archivebox`, standard toolbar button.

### Style

- Use standard macOS `.toolbar` content style. Do not customize button colors, shapes, or backgrounds. The toolbar should feel native.
- The warm `surface.canvas` background naturally bleeds into the toolbar area (macOS unified title bar behavior).
- Icon sizes: 16pt for SF Symbols, consistent with system toolbar conventions.

---

## 5. Status Bar

### Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  space.xl │ "15 tasks · 3 done this week · 0 overdue" │ space.xl    │
└──────────────────────────────────────────────────────────────────────┘
```

- Height: 28px
- Background: transparent (inherits `surface.canvas`)
- Top border: 0.5px `border.row`
- Text: `type.statusBar` (11pt Regular), `text.muted`
- Segments separated by " · " (interpunct with spaces)
- If overdue count > 0, that segment uses `status.overdue` color

---

## 6. Group Headers

### Layout

```
── PRIORITY A ────────────────────────────────────────────────
```

- Text: `type.groupHeader` (11pt Bold, allcaps, 1.0pt letterspacing), `text.secondary`
- Horizontal rule: 0.5px `border.row`, starts `space.md` after text, extends to right row edge
- Height: 28px
- Top margin: `space.2xl` (24px) from preceding row (except first group, which uses `space.md`)
- Bottom margin: `space.md` (8px) to first task row in the group
- Left padding: aligned with task text start (after circle + badge space)
- Not interactive, no hover state, no collapse affordance

### Group Labels by Sort Mode

| Sort | Groups |
|---|---|
| Priority | "PRIORITY A", "PRIORITY B", "PRIORITY C", "LOWER PRIORITY", "NO PRIORITY" |
| Due Date | "OVERDUE", "TODAY", "UPCOMING", "NO DUE DATE" |
| Project | "+SHIPPING", "+TAXES", "+BLOG", "NO PROJECT" |
| Context | "@WORK", "@HOME", "@PHONE", "NO CONTEXT" |
| Creation Date | "THIS WEEK", "LAST WEEK", "OLDER", "NO DATE" |
| File Order | (no groups — flat list) |
| Alphabetical | (no groups — flat list) |

---

## 7. Search Overlay

### Layout

- Floating panel, horizontally centered in the content area, 48px below the toolbar bottom
- Width: 400px
- Corner radius: `radius.lg` (10px)
- Shadow: `shadow.search`
- Background: `surface.input`

```
┌─ radius.lg ──────────────────────────────────────────────────┐
│  space.xl │ 🔍 │ space.sm │ search text field │ space.xl      │
└──────────────────────────────────────────────────────────────┘
```

- 🔍 icon: SF Symbol `magnifyingglass`, 14pt, `text.muted`
- Text field: `type.taskBody` (14pt), `text.primary`
- Placeholder: "Search tasks..." in `text.muted`, italic
- Height: 44px

### Search Active State

- Non-matching rows fade to `opacity.searchDimmed` (0.35)
- Matching text within surviving rows: highlighted with `syntax.project` at 20% opacity background, `radius.sm` corners
- When search is dismissed with Return (keeping filter), a pill appears below the input bar: "Showing results for '{query}' ×" — `type.taskMeta` size, `surface.hover` background, `radius.sm`, clickable × to clear

---

## 8. Undo Toast

- Position: bottom center of content area, `space.xl` above the status bar
- Background: `surface.toast` (inverted — dark in light mode, light in dark mode)
- Shadow: `shadow.toast`
- Corner radius: `radius.md` (8px)
- Padding: `space.md` vertical, `space.xl` horizontal
- Text: "Task completed · Undo" — `type.toastMessage` (12pt Medium), `text.inverse`
- "Undo" is styled as a link: underlined or uses a slightly brighter tint of `text.inverse`
- Clicking "Undo" triggers `Cmd+Z` and dismisses the toast immediately

---

## 9. Conflict Banner

- Position: between input bar and task list, full content width minus `space.xl` margins
- Background: `status.conflict` at 10% opacity
- Corner radius: `radius.md` (8px)
- Padding: `space.md` vertical, `space.xl` horizontal
- Left: SF Symbol `exclamationmark.triangle.fill`, `status.conflict` color, 14pt
- Center text: "todo.txt changed externally." — `type.taskBody`, `text.primary`
- Right: three text links — "Reload" | "Keep Mine" | "View Diff" — system accent color, `type.taskMeta` size, separated by `text.muted` " | "
- Bottom margin: `space.md` to first task row

---

## 10. Quick-Add Panel

- NSPanel, floating, borderless
- Centered horizontally on screen, positioned at 1/3 from the top
- Width: 480px
- Background: NSVisualEffectView `.popover` material (system vibrancy)
- Corner radius: `radius.lg` (10px)
- Shadow: `shadow.quickAdd`

### Content

```
┌─────────────────────────────────────────────────────────────┐
│  space.2xl padding                                          │
│  "Add to todo.txt" — type.inputHint, text.muted             │
│  space.sm                                                    │
│  ┌─ text field ──────────────────────────────────────────┐  │
│  │  type.inputBar, text.primary                           │  │
│  └────────────────────────────────────────────────────────┘  │
│  space.sm                                                    │
│  (date preview, only when date expression detected)          │
│  space.2xl padding                                          │
└─────────────────────────────────────────────────────────────┘
```

- Text field has no visible border — it floats on the vibrancy background
- Return commits and dismisses; Escape dismisses without saving
- Appear/dismiss: `anim.quickAdd.in` / `anim.quickAdd.out`

---

## 11. Empty States

- Vertically and horizontally centered in the content area (below input bar, above status bar)
- Text: `type.emptyState` (14pt Regular), `text.muted`
- Single line, no icon, no illustration
- If the message includes a keyboard shortcut (e.g., "⌘N"), render the shortcut in a slightly different weight or in a subtle `surface.input` background pill

---

## 12. Preferences Window

Standard macOS preferences window with tab bar. Not a focus of the visual revamp — use standard AppKit/SwiftUI form controls and system styling. The warm `surface.canvas` background should apply to the preferences window background if possible without fighting system controls.

Tab bar items: General, Appearance, Shortcuts, Advanced — each with an SF Symbol icon per standard macOS conventions.

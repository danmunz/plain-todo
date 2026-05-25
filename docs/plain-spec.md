# Plain — macOS Native todo.txt Client

## Product Spec v0.1

---

## 1. Vision

A fast, native, keyboard-first macOS app for managing a single todo.txt file synced via iCloud Drive. The app is a good citizen of the plaintext ecosystem: the .txt file is the source of truth, and the app never writes anything that would confuse another todo.txt client.

**Design philosophy:** Think Things 3 meets a text editor. The app should feel like a precision tool — quiet, fast, opinionated about workflow but not about your data. It earns its place on a developer/power-user's dock by being the fastest way to capture, triage, and complete tasks from a Mac.

---

## 2. Brand Identity

### 2.1 Name & Positioning

**Plain** — a todo.txt client for macOS.

The name works on three levels: it's a plaintext tool, it has a plain (unadorned) interface, and it's plain (obvious, self-evident) how to use it. The name is a quiet declaration of values: we think simplicity is a feature, not a limitation.

**Positioning statement:** Plain is the macOS todo.txt client for people who chose plaintext on purpose. It's fast, native, and stays out of your way. Your tasks live in a .txt file you own. Plain just makes that file pleasant to work with.

**What Plain is not:** It's not a project management tool. It's not a second brain. It's not a platform. It doesn't have an opinion about your productivity system. It has an opinion about file integrity, keyboard shortcuts, and not wasting your time.

### 2.2 Brand Voice

Plain's voice is **confident, dry, and warm** — like a tool that's good enough not to need to explain itself, made by someone who respects your time. It's the voice of a well-written README, not a marketing page.

**Tone principles:**

- **Say less.** If a tooltip can be three words, it's three words. If an empty state can be one sentence, it's one sentence. The app's restraint in features should be matched by restraint in language.
- **Be direct, not curt.** "Point Plain at your todo.txt file" is better than "Welcome to Plain! To get started, you'll need to select a todo.txt file from your filesystem." But it's also better than "Select file."
- **Dry humor, deployed sparingly.** An empty filter state can say "No @errands — nice." The about box can have a subtle joke. But the primary UI should never be clever at the expense of clarity. Humor is seasoning, not the dish.
- **Respect the user's expertise.** Don't explain what todo.txt is (link to the spec instead). Don't explain what iCloud Drive is. Don't explain what a keyboard shortcut is. The person using this app chose plaintext over Todoist — they know what they're doing.
- **No exclamation marks.** Almost never. The app is calm. "Task archived." not "Task archived!"

**Voice examples:**

| Context | Good | Bad |
|---|---|---|
| First launch heading | Point Plain at your todo.txt file. | Welcome to Plain! Let's get you set up with your productivity journey. |
| Empty task list | Nothing here yet. Cmd+N to add a task. | 🎉 Your task list is empty! Start adding tasks to get organized! |
| Empty filter result | No @errands tasks. | We couldn't find any tasks matching your filter criteria. Try adjusting your selection. |
| Archive confirmation | Archive 15 completed tasks to done.txt? | You're about to move 15 completed tasks to your done.txt archive file. This action can be undone. Would you like to proceed? |
| Sync conflict banner | todo.txt changed externally. | ⚠️ Warning: An external application has modified your todo.txt file while you had unsaved changes. |
| About box | Plain reads your todo.txt. That's it, really. | Plain is a powerful yet intuitive macOS application designed to help you manage your todo.txt files with ease and efficiency. |
| Error: file not found | Can't find todo.txt. Waiting for iCloud to sync, or choose a different file. | Error: The specified file path could not be located. Please verify that iCloud Drive sync is enabled and functioning correctly. |

### 2.3 Logo & Icon

The app icon should work at every macOS size (16×16 in the menu bar through 1024×1024 in the App Store) and feel at home next to system apps.

**Concept:** A rounded-rect macOS app icon with a single typographic element — the word "txt" or just "t" set in a clean monospace font, centered on a neutral background. No gradients, no gloss, no metaphorical objects (no checkboxes, no clipboards, no pencils). The icon *is* the format: text.

**Color palette for the icon:**
- Background: a warm off-white (#F5F3EF) in light mode / a deep warm gray (#2C2A28) in dark mode. Not pure white, not pure black — the slight warmth signals that this is a considered design choice, not a default.
- Text element: a single accent color. Candidates:
  - **Warm charcoal** (#3D3B38) — almost black, maximum restraint. The icon whispers.
  - **Muted teal** (#4A8B8C) — a hint of color, ties to the +project syntax highlighting in the app. Distinguishable on the dock.
  - **Slate blue** (#5B7B95) — calm, professional, doesn't compete with system icons.

The icon should be recognizable as "the plain one" on a crowded dock — not by being loud, but by being the quietest thing there.

**Wordmark:** "Plain" set in the system font (SF Pro) or a clean humanist sans (Inter, Söhne) at medium weight. No custom lettering, no ligatures, no tricks. Used in the about box, website, and App Store listing. Lowercase "plain" is an option — it's more approachable and matches the understated tone.

### 2.4 Color Identity

Plain's color identity is deliberately restrained. The app inherits most of its palette from macOS system colors (respecting light/dark mode and the user's accent color). The brand's own colors appear only in:

- The app icon
- The website/marketing (if any)
- The syntax highlighting palette (teal for +projects, violet for @contexts — these are functional, but they become associated with the brand through repeated use)

There is no "Plain blue" or "Plain green." The brand's visual identity is defined by *absence* of strong color — by the quietness of the interface, the quality of the typography, and the generous whitespace. This is a brand that looks like good taste, not like a color swatch.

### 2.5 Marketing Language (App Store / Website)

The same voice principles apply, but slightly warmer — you're talking to someone who hasn't used the app yet, so you need to earn a click without betraying the brand's restraint.

**App Store subtitle:** A todo.txt client that stays out of your way.

**App Store description (draft):**

> Plain is a native macOS client for todo.txt — the plaintext task format that you own, you control, and you can read with any text editor.
>
> Point it at your todo.txt file on iCloud Drive (or anywhere else). Plain gives you fast capture, keyboard-first navigation, syntax highlighting, smart filtering by project and context, and a global quick-add hotkey — then gets out of your way.
>
> Your tasks are a text file. Plain just makes that file pleasant to work with.
>
> — Syncs via iCloud Drive (or any file sync service)
> — Keyboard-first: capture, triage, and complete without touching the mouse
> — Smart filtering by +project, @context, and priority
> — Global quick-add from any app
> — macOS widget for at-a-glance awareness
> — Respects the todo.txt spec. No lock-in. No proprietary formats. No account.

**What to avoid in marketing copy:**
- "Supercharge your productivity"
- "The ultimate todo app"
- "Powerful yet simple" (the most meaningless phrase in software marketing)
- Any claim about AI, ML, or smart features
- Comparison to other apps by name (let the product speak)
- Screenshots with fake task lists full of aspirational tasks like "Launch startup" and "Learn Japanese" — use boring, real-sounding tasks

---

## 2. Feature Tiers (Kano Model)

### 2.1 Basic Features (Must-Have)

Absence of any of these makes the app unusable. These are non-negotiable for v1.

#### File Integrity & Sync

- Read and write the canonical todo.txt format with zero data loss. Round-trip fidelity on every save — no reordering lines, no stripping whitespace, no mangling key:value pairs the app doesn't understand.
- Point the app at any .txt file path, including `~/Library/Mobile Documents/` (iCloud Drive). No opinionated file location.
- Detect external file changes via `DispatchSource` / `FSEvents` and reload without clobbering in-progress edits.
- Conflict handling: if the file changed on disk while unsaved edits exist, surface a clear prompt — "File changed externally. Reload, keep yours, or view diff?" Never silently overwrite.
- Use `NSFilePresenter` / `NSFileCoordinator` for iCloud-safe file access.
- Support both `todo.txt` and `done.txt` (completed task archive).

#### Core Task Management

- Add, edit, complete, delete tasks.
- Set priority `(A)` through `(Z)`.
- Add creation date and completion date per the todo.txt spec.
- Inline editing — click a task, edit the raw text directly, not through a modal.
- Undo/redo (Cmd+Z / Cmd+Shift+Z) for all destructive operations. Implement via the standard `UndoManager` stack.

#### Filtering & Sorting

- Filter by project (`+tag`), context (`@tag`), priority.
- Sort by priority, creation date, alphabetical, or file order.
- Search / live filter across all tasks (Cmd+F or a persistent filter bar).

#### Keyboard-First Interaction

- `Cmd+N` — add a task (focus lands in new-task input).
- `Return` — confirm edit/add. `Escape` — cancel.
- `↑` / `↓` or `j` / `k` — navigate the task list.
- `Space` or `Cmd+D` — toggle task completion.
- Standard macOS text editing shortcuts in all text fields.

---

### 2.2 Performance Features (More-Is-Better)

Each improvement here makes daily use noticeably better.

#### Smart Filtering UI

- Sidebar showing all discovered `+projects` and `@contexts` from the file, with task counts.
- Combinable filters — e.g., show `@work +shipping` priority A–B.
- Saved filter presets (pin frequently-used views).
- Virtual filters for `due:` dates — "Due today," "Overdue," "Due this week."

#### Speed & Responsiveness

- Sub-100ms open-to-render for files up to several thousand tasks.
- Native-snappy text input — no perceptible lag in add/edit fields.
- Background file watching with minimal battery impact (coalesce FSEvents, no polling).

#### Bulk Operations

- Multi-select via `Shift+Click`, `Cmd+Click`.
- Bulk complete, bulk re-prioritize, bulk add/remove a `+project` or `@context`.
- Drag-to-reorder (reorder = reorder lines in the file).

#### Archive Management

- One-click "archive completed" — moves `x` tasks to `done.txt`.
- Option: auto-archive on completion or accumulate and archive manually.
- View `done.txt` via the "Done" section in the sidebar — read-only, reverse-chronological.

#### Polish

- Respect system appearance (light/dark mode, accent color).
- Remember window size, position, and last-used file path.
- Menu bar item or global hotkey for quick-add without bringing the full window forward.

---

### 2.3 Delight Features (Attractive)

These aren't expected. Their absence doesn't hurt, but their presence creates loyalty.

#### Natural Language Quick-Add (Date Parsing Only)

- Parse relative date expressions in the input: "tomorrow," "friday," "next Tuesday," "end of month," "june 5" → `due:YYYY-MM-DD`. This is the only natural language transformation the parser performs.
- All other todo.txt syntax — priorities `(A)`, `+projects`, `@contexts`, `key:value` pairs — must be typed explicitly by the user. This keeps the parser trustworthy: it only does one thing, and you can predict what it will do.
- Show a live preview of the parsed todo.txt line below the input bar before committing so the user can verify date interpretation. The preview only appears when a date expression is detected; otherwise the input is passed through verbatim.

#### Inline Syntax Highlighting

- In both the task list and the edit field, visually distinguish priorities (color-coded), `+projects`, `@contexts`, dates, and `key:value` pairs.
- Subtle typographic differentiation — not garish, just enough to make scanning fast.

#### Scratch Pad Mode

- `Cmd+E` toggles to a raw plaintext editor view of the entire file.
- Useful for power-user batch edits, copy/paste, or "I want to see what's actually in the file."
- Changes round-trip back to the structured view on toggle.

#### Ambient Stats

- Small footer: "47 tasks · 12 done this week · 3 overdue."
- Nothing gamified — just quiet awareness.

#### Global Quick-Add

- System-wide hotkey (e.g., `Ctrl+Option+T`) pops a floating text field.
- Type a task, hit Enter, it appends to `todo.txt` and disappears.
- No need to switch to the app for task capture.

#### Thoughtful Empty States

- When a filter returns no results: contextual, useful messages ("No @errands — nice.").
- First-launch onboarding: point at a file, explain the format in 30 seconds.

---

### 2.4 Explicit Non-Goals

- **No proprietary sync.** iCloud Drive is the sync layer. Don't reinvent it.
- **No database or index file.** The .txt file is the only persistent state. Preferences go in `UserDefaults`.
- **No Reminders/Calendar integration.** Stay in lane.
- **No custom format extensions.** If it's not in the todo.txt spec or a widely-adopted convention (like `due:`), don't invent it.
- **No multi-file management.** Support one `todo.txt` and one `done.txt`. Users with multiple lists can switch files, but don't build a file manager.

---

## 3. UI Design

### 3.1 Layout Architecture

The window uses a two-panel layout with an optional sidebar. The design borrows spatial logic from apps like Things, Bear, and Sublime Text — but stays closer to a text editor's sensibility than a project management tool's.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Traffic Lights              Plain                    (toolbar)     │
├─────────────┬────────────────────────────────────────────────────────┤
│             │  ┌──────────────────────────────────────────────────┐  │
│  SIDEBAR    │  │  + Add a task...                          Cmd+N │  │
│             │  ├──────────────────────────────────────────────────┤  │
│  Inbox   47 │  │                                                 │  │
│  Today    3 │  │  (A) Call accountant @phone +taxes    due:05-29 │  │
│  Overdue  1 │  │  (B) Review Q3 deck @work +shipping             │  │
│             │  │  (C) Fix garden hose @home                      │  │
│  ─────────  │  │      Pick up Ava's cleats @errands              │  │
│  +projects  │  │      Write up MoCA networking post +blog        │  │
│   shipping 4│  │  x   2026-05-20 Return router @errands          │  │
│   taxes    2│  │                                                 │  │
│   blog     1│  │                                                 │  │
│             │  │                                                 │  │
│  @contexts  │  │                                                 │  │
│   @work    8│  │                                                 │  │
│   @home    5│  │                                                 │  │
│   @phone   2│  │                                                 │  │
│   @errands 3│  │                                                 │  │
│             │  │                                                 │  │
│  ─────────  │  │                                                 │  │
│  Done    128│  │                                                 │  │
│             │  ├──────────────────────────────────────────────────┤  │
│             │  │  47 tasks · 12 done this week · 1 overdue       │  │
└─────────────┴──┴──────────────────────────────────────────────────┘  │
```

#### Panel Breakdown

**Sidebar (left, collapsible)**

- Width: ~200px, resizable, collapsible via `Cmd+\` or a toolbar toggle. State persists across launches.
- **Smart Filters section** (top): "Inbox" (all incomplete), "Today" (due today), "Overdue" (past due date). These are virtual — derived from file content, not stored anywhere.
- **+projects section**: Auto-populated from every `+tag` in the file. Sorted alphabetically. Each row shows the tag name and an unobtrusive task count. Clicking filters the main list.
- **@contexts section**: Same pattern as projects.
- **Done section** (bottom, below a separator): A single row — "Done" with a count of tasks in `done.txt`. Clicking it replaces the main task list with a read-only view of `done.txt`, sorted reverse-chronologically (most recently completed first). The view uses the same task row styling but with all rows in the completed/dimmed state. No editing, no completion toggles. A "Back to tasks" link or pressing `Escape` returns to the active list. This keeps the archive accessible without cluttering the primary workspace.
- Selecting a sidebar item is a filter, not a navigation — it narrows the main list. The selected item gets a subtle highlight (system accent color, low opacity). Multiple selections via Cmd+Click for combinable filters.
- Each sidebar filter remembers its own sort order independently. Switching from `@work` (sorted by priority) to `+shipping` (sorted by date) restores each filter's last-used sort. "Inbox" has its own default. Sort preference is stored in `UserDefaults`, keyed by filter name.
- A small "×" or "Clear" affordance appears when any filter is active, restoring the full list.

**Main Panel (right, always visible)**

Three vertical zones:

1. **Input bar** (top, persistent): A single-line text field with placeholder "Add a task..." and a muted `Cmd+N` hint. Always visible, always ready. Pressing `Cmd+N` from anywhere focuses this field. Typing and pressing `Return` appends the task to the bottom of the file (per todo.txt convention). The list scrolls to the newly added task and briefly highlights it (~1s pulse in the accent color at low opacity) so you can confirm it landed correctly. The input field clears and remains focused for rapid successive entry (batch capture mode). Pressing `Escape` blurs the field back to the task list.

2. **Task list** (middle, scrollable): The core of the app. Each task occupies a single row. This is not a table — it's a styled text list, closer to a code editor's line display than a spreadsheet.

3. **Status bar** (bottom, persistent): A single line of ambient stats. Muted text, small type. "47 tasks · 12 done this week · 1 overdue." Updates live as you work.

---

### 3.2 Task Row Design

Each task row is the most important piece of UI in the app. It must be scannable, information-dense without being cluttered, and instantly editable.

```
┌──────────────────────────────────────────────────────────────────┐
│ ○  (A)  Call accountant @phone +taxes              due:May 29   │
│ ○  (B)  Review Q3 deck @work +shipping                          │
│ ○       Pick up Ava's cleats @errands                           │
│ ●  x    2026-05-20 Return router @errands                       │
└──────────────────────────────────────────────────────────────────┘
```

#### Row Anatomy (left to right)

1. **Completion toggle**: A circle. Empty (○) for incomplete, filled (●) for complete. Click to toggle. On completion, the task gets the `x` prefix and today's date per spec. A brief strikethrough animation plays, and the row dims (reduced opacity, ~0.5) but remains in place until archived.

2. **Priority badge**: If the task has a priority, show it as `(A)`, `(B)`, etc. Color-coded:
   - `(A)` — Red/warm (high urgency)
   - `(B)` — Amber/orange
   - `(C)` — Blue/cool
   - `(D)` and below — Gray/muted
   - No priority — no badge, the space collapses so unprioritized tasks don't have an awkward gap.

3. **Task text**: The body of the task, rendered with inline syntax highlighting:
   - `+project` tags — rendered in a distinct color (e.g., a muted teal), slightly bolder weight.
   - `@context` tags — rendered in a second distinct color (e.g., a muted violet).
   - `key:value` pairs — rendered in a third color (e.g., a warm gray), slightly smaller or lighter.
   - Plain text — standard system font, regular weight.
   - The text is **not** a rendered/transformed version of the line — it's the actual todo.txt content with typographic styling applied. What you see is what's in the file, just prettier.

4. **Due date** (right-aligned, if present): If a `due:YYYY-MM-DD` value exists, show it right-aligned in a human-friendly format ("May 29", "Tomorrow", "Overdue" in red). This is the only piece of derived/formatted data in the row.

#### Row Interaction States

- **Default**: Row has a subtle bottom border (1px, very light). No background.
- **Hover**: Faint background highlight. A small "···" menu icon fades in at the right edge (for mouse-only users who don't know the keyboard shortcuts).
- **Selected/Focused** (keyboard navigation): Slightly stronger background highlight, system accent color at low opacity. A subtle left-edge indicator (2px accent-colored bar) marks the focused row, similar to Xcode's line highlight.
- **Editing**: Clicking the task text (or pressing `Return` on a focused row) transforms the row into an inline text field. The text becomes fully editable, cursor placed at click position. The row expands slightly in height if needed. Syntax highlighting remains active during editing. `Return` saves, `Escape` cancels. The edit field shows the raw todo.txt line — no hidden transformations.
- **Completed**: On toggle, a ~1s animation sequence plays: the completion circle fills, then the task text receives a left-to-right strikethrough wipe, then the row fades to reduced opacity (~0.5). A small undo toast appears at the bottom of the task list ("Task completed · Undo") for ~4 seconds. Clicking "Undo" or pressing `Cmd+Z` reverts the completion instantly. The row stays in its current position (not reordered) until manually or auto-archived.
- **Dragging**: Row lifts with a subtle shadow, other rows make space. Drop position = new line position in the file.

---

### 3.3 Input Bar Design

The input bar is permanently docked at the top of the main panel. It's the primary capture surface.

```
┌──────────────────────────────────────────────────────────────────┐
│  +   Add a task...                                        Cmd+N │
└──────────────────────────────────────────────────────────────────┘
```

**Unfocused state**: Muted placeholder text, a `+` icon at the left, `Cmd+N` shortcut hint at the right. The whole bar is a click target.

**Focused state**: Placeholder disappears, cursor appears, the bar gains a subtle bottom border or glow in the accent color. The `Cmd+N` hint disappears (you're already here). As you type, the date parser watches for relative date expressions:

```
┌──────────────────────────────────────────────────────────────────┐
│  +   (A) Call accountant friday @phone +taxes                   │
│      ┌────────────────────────────────────────────────────────┐  │
│      │  → (A) 2026-05-22 Call accountant due:2026-05-29      │  │
│      │    @phone +taxes                                       │  │
│      └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

A live preview tooltip appears below the input only when a date expression is detected, showing how "friday" will be resolved to `due:2026-05-29`. The preview uses the same syntax highlighting as the task list. If no date expression is found, the input is passed through verbatim with no preview — the user typed valid todo.txt syntax and the app trusts it.

**Batch capture**: After pressing `Return`, the task is appended and the field clears but stays focused. You can keep typing tasks. This is critical for inbox-dump moments — you want to capture five things in rapid succession without any friction.

---

### 3.4 Toolbar

The toolbar is minimal. macOS apps should use the native toolbar area, not reinvent it.

```
┌──────────────────────────────────────────────────────────────────┐
│  ◀▶  Sidebar Toggle  │  Sort: Priority ▾  │  ⚙  │  📝 Scratch  │
└──────────────────────────────────────────────────────────────────┘
```

- **Sidebar toggle**: Show/hide the sidebar. `Cmd+\`.
- **Sort menu**: Dropdown — Priority, Date, Alphabetical, File Order. Keyboard shortcut `Cmd+Shift+S` cycles through.
- **Settings gear**: Opens preferences (file path, archive behavior, hotkey config, appearance).
- **Scratch pad toggle**: Switches to raw text editor mode. `Cmd+E`.

The toolbar uses SF Symbols for icons — native, resolution-independent, and consistent with macOS conventions.

---

### 3.5 Search (Cmd+F)

Search is a transient, floating overlay — Spotlight-style — not a persistent filter bar. It's a different mechanism from the sidebar filters: the sidebar is for structured, ongoing filtering by project/context/priority; search is for ad hoc text lookup.

```
          ┌──────────────────────────────────────┐
          │  🔍  expense report                   │
          └──────────────────────────────────────┘
```

- `Cmd+F` opens a floating search field centered above the task list (similar to Spotlight or the Safari tab search).
- As you type, the task list live-filters to matching rows. Matching is substring, case-insensitive, across the full raw line (so searching "work" matches both `@work` and the word "work" in a task body).
- Matched text is highlighted in each visible row (subtle background highlight on the matching substring).
- `Return` dismisses the search field but keeps the filter active, allowing you to interact with the filtered list. A small "Showing results for 'expense report' ×" pill appears below the input bar to indicate an active search filter.
- `Escape` dismisses the search field and clears the filter, restoring the full list.
- Search and sidebar filters are combinable: if you have `@work` selected in the sidebar and search for "expense," you see only `@work` tasks containing "expense."

---

### 3.6 Task List Grouping

When the task list is sorted, tasks are visually grouped by the sort dimension. Group headers are always expanded — they're visual separators, not collapsible containers. This aids scanning without hiding tasks.

**Sort by priority → group by priority band:**
```
  ── Priority A ──────────────────────────────────
  ○  (A)  Call accountant @phone +taxes
  ○  (A)  Submit expense report @work
  ── Priority B ──────────────────────────────────
  ○  (B)  Review Q3 deck @work +shipping
  ── No Priority ─────────────────────────────────
  ○       Pick up Ava's cleats @errands
  ○       Write up MoCA networking post +blog
```

**Sort by project → group by +project:**
```
  ── +shipping ───────────────────────────────────
  ○  (B)  Review Q3 deck @work +shipping
  ○       Check tracking numbers @work +shipping
  ── +taxes ──────────────────────────────────────
  ○  (A)  Call accountant @phone +taxes
  ── +blog ───────────────────────────────────────
  ○       Write up MoCA networking post +blog
  ── (no project) ────────────────────────────────
  ○       Pick up Ava's cleats @errands
```

**Sort by context → group by @context. Sort by date → group by date bucket** (Today, This Week, Later, No Date). Sort by file order or alphabetical → no grouping (flat list).

Group headers are lightweight: a thin horizontal rule with the group label in muted, small text. They occupy minimal vertical space and don't compete with the task rows for attention. Tasks that belong to multiple groups (e.g., a task with both `+shipping` and `+blog`) appear in the group corresponding to the primary sort — the first tag in the line, per todo.txt convention.

---

### 3.7 Scratch Pad Mode

When toggled, the main panel replaces the task list with a full plaintext editor showing the raw contents of `todo.txt`. This is essentially a built-in TextEdit view of the file.

```
┌──────────────────────────────────────────────────────────────────┐
│  Scratch Pad — todo.txt                              ✕ Close    │
├──────────────────────────────────────────────────────────────────┤
│  1  (A) 2026-05-22 Call accountant due:2026-05-29 @phone +taxes │
│  2  (B) 2026-05-20 Review Q3 deck @work +shipping              │
│  3  Pick up Ava's cleats @errands                               │
│  4  Write up MoCA networking post +blog                         │
│  5  x 2026-05-20 2026-05-18 Return router @errands              │
└──────────────────────────────────────────────────────────────────┘
```

- Line numbers displayed (like a code editor).
- Syntax highlighting active on the raw text.
- Monospace font (SF Mono or Menlo) — this is "file editing" mode and should feel like it.
- Standard text editor behavior: select, cut, copy, paste, find/replace (`Cmd+F` in this mode triggers in-editor find, not the task list filter).
- On exiting scratch pad mode (`Cmd+E` again or clicking close), the file is re-parsed and the structured task list rebuilds. If there are parse issues (malformed lines), they're displayed as-is with a subtle warning indicator — the app never refuses to show a line it can't fully parse.

---

### 3.8 Global Quick-Add Panel

A floating, borderless window that appears system-wide when the global hotkey is pressed. Think Spotlight or Alfred — minimal, transient, single-purpose.

```
              ┌────────────────────────────────────────┐
              │  Add to todo.txt...                    │
              │                                        │
              │  ┌──────────────────────────────────┐  │
              │  │                                  │  │
              │  └──────────────────────────────────┘  │
              │  → preview of parsed line appears here │
              └────────────────────────────────────────┘
```

- Appears centered, upper-third of the screen.
- Single text field. Same natural language parsing and preview as the in-app input bar.
- `Return` saves and dismisses. `Escape` dismisses without saving.
- No other UI — no task list, no sidebar, no toolbar. Pure capture.
- Vibrancy / blur background (NSVisualEffectView) to feel native and transient.
- The panel works even when the main app window is closed or hidden. It only requires the app to be running (in the menu bar).

---

### 3.9 Menu Bar Presence

The app can optionally live in the macOS menu bar with a small icon (a checkbox or a "t" glyph). Clicking the menu bar icon reveals a compact dropdown:

```
              ┌──────────────────────────┐
              │  + Add a task...         │
              ├──────────────────────────┤
              │  Today          3 tasks  │
              │  Overdue        1 task   │
              ├──────────────────────────┤
              │  Open Plain     Cmd+O   │
              │  Preferences...          │
              │  Quit                    │
              └──────────────────────────┘
```

- The quick-add field is embedded at the top of the dropdown.
- "Today" and "Overdue" counts give at-a-glance awareness.
- Clicking "Open Plain" brings the main window forward.
- This is the lightest-weight interaction mode — you can glance at your task load and capture a thought without ever opening a window.

---

### 3.10 Keyboard Shortcut Map

The app is keyboard-first. Every common action has a shortcut, and the shortcuts follow macOS conventions wherever possible.

| Action | Shortcut | Context |
|---|---|---|
| New task | `Cmd+N` | Global (within app) |
| Complete task | `Space` or `Cmd+D` | Task focused |
| Edit task | `Return` | Task focused |
| Delete task | `Cmd+Backspace` | Task focused (with undo) |
| Navigate up | `↑` or `K` | Task list |
| Navigate down | `↓` or `J` | Task list |
| Move task up | `Opt+↑` | Task focused |
| Move task down | `Opt+↓` | Task focused |
| Set priority A | `Cmd+1` | Task focused or editing |
| Set priority B | `Cmd+2` | Task focused or editing |
| Set priority C | `Cmd+3` | Task focused or editing |
| Remove priority | `Cmd+0` | Task focused or editing |
| Toggle sidebar | `Cmd+\` | Global |
| Toggle scratch pad | `Cmd+E` | Global |
| Search / filter | `Cmd+F` | Global (opens floating search) |
| Dismiss search | `Escape` | When search field is focused |
| Archive completed | `Cmd+Shift+A` | Global |
| Cycle sort mode | `Cmd+Shift+S` | Global |
| Undo | `Cmd+Z` | Global |
| Redo | `Cmd+Shift+Z` | Global |
| Quick-add (system) | `Ctrl+Opt+T` | System-wide (configurable) |
| Select multiple | `Shift+↑/↓` | Task list |
| Select all | `Cmd+A` | Task list |
| Open preferences | `Cmd+,` | Global |

The `j`/`k` navigation only activates when the focus is on the task list (not in a text field). This avoids the Vim-binding pitfall of intercepting normal typing.

---

### 3.11 Typography ### 3.9 Typography & Color Color

#### Typography

- **Task list body**: System font (SF Pro) at 13–14pt, regular weight. This is a productivity tool, not a design showcase — the system font is the right call for readability and native feel.
- **Priority badges**: Same font, semi-bold, in the priority color.
- **Sidebar labels**: 12pt, medium weight. Counts in regular weight, muted color.
- **Input bar**: 14pt, matching the task list. Placeholder in italic, muted.
- **Status bar**: 11pt, muted color.
- **Scratch pad**: SF Mono or Menlo, 13pt. Monospace signals "you're editing a file."

#### Color System

All colors derive from semantic tokens, not hardcoded values. This ensures light/dark mode works automatically and users who customize their macOS accent color get coherent results.

| Token | Light Mode | Dark Mode | Usage |
|---|---|---|---|
| `text.primary` | gray-900 | gray-100 | Task body text |
| `text.muted` | gray-400 | gray-500 | Dates, counts, status bar |
| `priority.A` | red-600 | red-400 | Priority A badge + text |
| `priority.B` | amber-600 | amber-400 | Priority B |
| `priority.C` | blue-600 | blue-400 | Priority C |
| `priority.low` | gray-400 | gray-500 | Priority D+ |
| `tag.project` | teal-600 | teal-400 | +project tags |
| `tag.context` | violet-600 | violet-400 | @context tags |
| `tag.keyvalue` | gray-500 | gray-400 | key:value metadata |
| `surface.hover` | gray-100 | gray-800 | Row hover state |
| `surface.selected` | accent/10% | accent/15% | Row selected state |
| `border.row` | gray-100 | gray-800 | Row separator |
| `accent` | system accent | system accent | Focus rings, active filter |
| `danger` | red-600 | red-400 | Overdue dates, delete confirm |

The syntax highlighting colors (project, context, key:value) are deliberately muted — they aid scanning without making the task list look like a Christmas tree. Think syntax highlighting in a well-configured code editor (Solarized, One Dark) rather than a children's toy.

---

### 3.12 Animations & Transitions

Animations should be fast (150–250ms), purposeful, and native-feeling. No gratuitous motion.

- **Task completion**: After a ~1s delay (allowing undo), the circle fills with a brief scale-up (100% → 110% → 100%), text gets strikethrough with a left-to-right wipe, row fades to reduced opacity. An undo toast ("Task completed · Undo") appears at the bottom for ~4 seconds. Total animation duration: ~300ms, but perceived as a deliberate beat because of the delay.
- **Task addition**: The list scrolls to the bottom, and the new row fades in with a brief accent-colored background pulse (~1s) to draw the eye, then settles to the default row style. ~250ms for the scroll + fade.
- **Task deletion**: Row collapses vertically with a fade-out. ~200ms. The undo toast appears at the bottom.
- **Sidebar expand/collapse**: Width animates smoothly. ~200ms. Content cross-fades.
- **Scratch pad toggle**: Cross-fade between structured view and text editor. ~200ms.
- **Filter change**: Task list cross-fades to the filtered set. No jarring full-list replacement.
- **Quick-add panel**: Fades in with a slight scale-up (98% → 100%). Dismisses with fade-out. ~150ms.
- **Search field**: Floats in from above with a fade, similar to Spotlight. ~150ms. Dismisses with reverse animation.

All animations respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` — if the user has reduced motion enabled, transitions become instant cuts.

---

### 3.13 Preferences

Accessed via `Cmd+,`. A standard macOS preferences window with a few tabs.

#### General

- **todo.txt file path**: File picker. Shows the current path. "Change..." button.
- **done.txt file path**: Defaults to same directory as todo.txt. Override if needed.
- **Archive behavior**: Radio — "Archive completed tasks automatically" / "Archive manually with Cmd+Shift+A."
- **New task creation date**: Toggle — "Automatically add creation date to new tasks" (default: on).
- **Default priority**: Dropdown — None, A, B, C (default: None).

#### Appearance

- **Theme**: "Follow system" / "Light" / "Dark" (default: Follow system).
- **Font size**: Slider, 11pt–18pt (default: 13pt).
- **Show completed tasks**: Toggle (default: on). When off, completed tasks are hidden from the list but remain in the file.

#### Shortcuts

- **Global quick-add hotkey**: Hotkey recorder. Default `Ctrl+Opt+T`.
- **Menu bar icon**: Toggle — show/hide.
- Keyboard shortcut reference (read-only table of all shortcuts).

#### Advanced

- **File encoding**: UTF-8 (display only — we always read/write UTF-8).
- **Backup**: Toggle — "Create .bak before writing" (default: off). If enabled, the app copies `todo.txt` to `todo.txt.bak` before each write.
- **Debug log**: Toggle for troubleshooting file sync issues.

---

### 3.14 Session Restore

The app restores full session state on launch, making it feel like it never quit:

- **Active sidebar filter** (which +project, @context, or smart filter was selected).
- **Sort order** for the active filter (per-filter sort memory).
- **Scroll position** in the task list.
- **Window frame** (size and position on screen).
- **Sidebar visibility** (expanded or collapsed).

All session state is stored in `UserDefaults`. If the underlying file has changed since last quit (e.g., tasks were added from the phone overnight), the session state is applied on top of the refreshed file content — the filter and sort are re-applied, and the scroll position is restored as closely as possible (anchored to the nearest surviving task if the original anchor task was removed).

If the stored file path is no longer accessible (file deleted, iCloud not synced yet), the app shows a non-blocking banner: "Waiting for todo.txt to sync from iCloud..." with a "Choose a different file" option. It does not fall back to the first-launch onboarding — the user has already set up the app and probably just needs to wait a moment.

### 3.15 Window Model

The app is single-window. There is always exactly one main window, one file, one task list. `Cmd+N` always focuses the input bar in that window; it never creates a new window.

The global quick-add panel and menu bar dropdown are separate UI surfaces but not "windows" in the macOS window management sense — they're transient panels that write to the same file. This keeps the mental model simple: one place for your tasks, multiple lightweight ways to add to it.

---

## 4. Interaction Patterns — Key Flows

### 4.1 First Launch

1. App opens with a centered welcome view (no sidebar, no task list).
2. Heading: "Point Plain at your todo.txt file."
3. Two options: "Open an existing file" (file picker) / "Create a new file" (save dialog).
4. Brief inline explanation of the todo.txt format — 3 sentences, not a tutorial. Link to todotxt.org for the full spec.
5. Once a file is selected, the app transitions to the standard two-panel layout. The file path is persisted in `UserDefaults`.

### 4.2 Capturing a Task

**From the main window:**
1. `Cmd+N` or click the input bar.
2. Type: "(B) Review PR friday @work +shipping"
3. Preview appears (because "friday" was detected): `(B) 2026-05-22 Review PR due:2026-05-29 @work +shipping`
4. `Return` — task is appended to the bottom of the file. The list scrolls down and briefly highlights the new row.
5. Input bar clears, stays focused. Type another task or press `Escape` to return focus to the task list.

**From the global quick-add:**
1. `Ctrl+Opt+T` from any app.
2. Floating panel appears. Type the task.
3. `Return` — task appended, panel disappears.
4. You're back in whatever app you were using. Total disruption: ~3 seconds.

**From the menu bar:**
1. Click the menu bar icon.
2. Type in the quick-add field at the top of the dropdown.
3. `Return` — task appended, dropdown dismisses.

### 4.3 Triaging / Working the List

1. Open the app. The task list shows all incomplete tasks in your current sort order.
2. Use `j`/`k` or arrow keys to scan down the list.
3. See a task that's now priority A: press `Cmd+1`. The priority badge updates, the row re-sorts if sorting by priority.
4. See a task that needs a context: press `Return` to edit inline, type ` @work`, press `Return` to save.
5. Complete a task: press `Space`. Circle fills, strikethrough animates, row dims.
6. Quick-filter to just `@work` tasks: click `@work` in the sidebar, or press `Cmd+F` and type `@work`.
7. Done with triage: press `Escape` to clear the filter and see the full list again.

### 4.4 Handling a Sync Conflict

1. You edit a task in the app.
2. Before you finish editing, the iPhone app syncs a change to the same file via iCloud.
3. `FSEvents` fires. The app detects the file's modification date has changed.
4. A non-modal banner appears at the top of the task list: "todo.txt was modified externally."
   - **"Reload"** — discards your in-progress edit and reloads the file from disk.
   - **"Keep Mine"** — writes your version to disk, overwriting the external change.
   - **"View Diff"** — opens a sheet showing the external changes vs. your version, line by line. You can choose per-line which version to keep. (This is the power-user option; most of the time "Reload" is correct because the phone edit and the desktop edit are on different tasks.)
5. If you don't interact with the banner within 30 seconds, it stays visible but doesn't block work. The app continues showing your in-memory version.

### 4.5 Archiving

1. You have 15 completed tasks cluttering the list.
2. Press `Cmd+Shift+A` or click "Archive completed" in the menu.
3. A confirmation: "Archive 15 completed tasks to done.txt?"
4. On confirm: completed tasks are removed from `todo.txt` and appended to `done.txt`. Both file writes are atomic — write to temp file, then rename.
5. The task list updates. The status bar reflects the new count.

---

## 5. Technical Considerations

### 5.1 Parser Design

The todo.txt parser is the foundation and must be rock-solid. It should be a standalone module with comprehensive test coverage.

**Parse pipeline:**
1. Read the file as UTF-8 text.
2. Split on newlines (handle `\n`, `\r\n`, and `\r`).
3. For each line, parse into a `TodoTask` struct:
   - Completed flag (`x ` prefix)
   - Completion date (if completed)
   - Priority `(A)`–`(Z)`
   - Creation date
   - Body text (everything remaining)
   - Extracted: `+project` tags, `@context` tags, `key:value` pairs
4. Preserve the original raw line text — always available for round-trip writing.
5. Lines that don't parse cleanly are kept as-is (raw text, no metadata). The app never discards or modifies a line it doesn't understand.

**Write pipeline:**
1. Reconstruct each line from the `TodoTask` struct, maintaining the original format as closely as possible.
2. Lines that were never edited are written back byte-for-byte identical.
3. Join with `\n`. Preserve trailing newline if the original file had one.
4. Write to a temp file in the same directory, then atomically rename.

### 5.2 File Coordination

- Use `NSFileCoordinator` for all reads and writes. This is essential for iCloud Drive compatibility — it coordinates with the iCloud daemon and prevents data loss during sync.
- Register as an `NSFilePresenter` to receive change notifications.
- On receiving a `presentedItemDidChange()` notification, compare file modification date with last-known date. If changed, trigger the reload/conflict flow.

### 5.3 Performance

- The parser should handle 10,000-line files in under 50ms on an M1 Mac. The format is simple enough that this is straightforward with Swift's string processing.
- The task list should use lazy rendering (SwiftUI `List` or `LazyVStack`) to handle large files without loading all rows into memory.
- File watching uses coalesced FSEvents — don't react to every intermediate write during an iCloud sync, wait for quiescence.

### 5.4 Accessibility

- Full VoiceOver support. Every task row has an accessible label composed of its priority, text, and due date.
- The completion toggle is an accessible button with clear state ("Mark as complete" / "Mark as incomplete").
- Keyboard navigation is already the primary interaction model, which inherently benefits accessibility.
- Respect Dynamic Type for the menu bar dropdown and quick-add panel.
- High-contrast mode support via semantic colors.

---

## 6. Resolved Design Decisions

- **Done.txt viewing**: The done.txt archive appears as a sidebar section below `@contexts`, separated by a divider. Clicking it shows a read-only, reverse-chronological list of completed tasks in the main panel. No editing, no toggles — it's a reference view. `Escape` returns to the active list.
- **Sort orders**: Per-filter sort memory. Each sidebar filter (including smart filters and each +project / @context) independently remembers its last-used sort order, stored in `UserDefaults`. This means `@work` can stay sorted by priority while `+shipping` stays sorted by date without re-sorting every time you switch.
- **Task IDs**: The todo.txt spec doesn't include IDs. For undo/redo and drag-reorder, we use line number + content hash as a transient in-memory identifier, never written to the file.
- **Recurring tasks**: Ignored for v1. The `rec:` extension is not in the core spec and adds meaningful complexity. If a `rec:` key:value pair appears in a task, it's preserved as-is but the app doesn't act on it.
- **Widget**: In scope for v1. See section 7.
- **New task position**: Append to bottom of the file, per todo.txt convention. The list scrolls to the new task and briefly highlights it to confirm placement.
- **Completion feedback**: Brief ~1s delay before the strikethrough animation plays, with an undo toast visible for ~4 seconds. The row dims in place (not removed from the list) until archived.
- **Task list grouping**: Tasks are visually grouped by the active sort dimension — priority bands when sorted by priority, +project headers when sorted by project, @context headers when sorted by context, date buckets when sorted by date. Group headers are always expanded (non-collapsible) — they're visual separators only. File order and alphabetical sorts produce a flat list with no grouping.
- **Natural language parsing scope**: Date expressions only ("friday," "tomorrow," "next tuesday," "june 5" → `due:YYYY-MM-DD`). All other todo.txt syntax must be typed explicitly. The preview line only appears when a date transformation is detected.
- **Search (Cmd+F)**: Floating Spotlight-style search field, not a persistent filter bar. Live-filters the task list as you type. Dismisses on Escape (clears filter) or Return (keeps filter active with a visible pill indicator). Combinable with sidebar filters.
- **Session restore**: Full state restored on launch — active filter, sort order, scroll position, window frame, sidebar visibility. The app feels like it never quit.
- **Window model**: Single window only. The quick-add panel and menu bar dropdown are transient surfaces, not separate windows.

---

## 7. macOS Widget

A WidgetKit widget for the Today view / Notification Center, providing at-a-glance task awareness without opening the app.

### 7.1 Widget Sizes

**Small (square)**
```
┌─────────────────────┐
│  Plain             │
│                     │
│  3 due today        │
│  1 overdue          │
│                     │
└─────────────────────┘
```
Counts only. Tapping opens the app with the "Today" smart filter active.

**Medium (wide)**
```
┌──────────────────────────────────────────┐
│  Plain                       3 today    │
│                                          │
│  (A) Call accountant @phone +taxes       │
│  (B) Review Q3 deck @work +shipping      │
│      Pick up Ava's cleats @errands       │
│                               1 overdue  │
└──────────────────────────────────────────┘
```
Shows up to 3–4 tasks due today (sorted by priority), plus today/overdue counts. Each task row is tappable and deep-links to that task in the app. If more tasks exist than fit, the last visible row shows "+2 more."

**Large (tall)**
```
┌──────────────────────────────────────────┐
│  Plain                       3 today    │
│                                          │
│  Today                                   │
│  (A) Call accountant @phone +taxes       │
│  (B) Review Q3 deck @work +shipping      │
│      Pick up Ava's cleats @errands       │
│                                          │
│  Overdue                                 │
│  (C) Submit expense report @work         │
│                                          │
│  Coming up                               │
│      Dentist appointment @phone  May 28  │
│      Ava's recital @home         Jun 2   │
│                                          │
│                              47 total    │
└──────────────────────────────────────────┘
```
Three sections: Today, Overdue, and Coming Up (next 7 days). Priority color-coding carries over from the main app. Tapping any task deep-links. Tapping the header opens the app.

### 7.2 Widget Technical Notes

- The widget reads `todo.txt` directly from the iCloud Drive path stored in the app's shared `UserDefaults` (via App Groups).
- The parser module is shared between the main app target and the widget extension target — same parsing logic, guaranteed consistency.
- Widget timeline: refresh every 15 minutes (WidgetKit minimum) or on significant date change (midnight rollover for "today" / "overdue" recalculation).
- The widget uses `FileManager` to read the file, not `NSFileCoordinator` — widgets run in a constrained environment and the read-only access pattern is safe here.
- Intent configuration: optionally let the user choose which smart filter the widget shows (Today, Overdue, a specific +project or @context). Default is the Today + Overdue combined view.
- Styling matches the main app's semantic color tokens. The widget respects light/dark mode and uses system font at slightly smaller sizes (11–12pt) to fit the constrained space.


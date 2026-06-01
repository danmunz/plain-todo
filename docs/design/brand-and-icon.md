# Plain — Brand & Icon Spec

Visual identity for surfaces outside the main task interface: app icon, about box, onboarding, empty states, and any marketing presence. Reference `design-tokens.md` for token values.

---

## App Icon

### Concept

A rounded-rect macOS app icon with a single typographic element. No metaphorical objects — no checkboxes, clipboards, pencils, or list icons. The icon *is* the format: text. It should be the quietest, most considered icon on a crowded dock.

### Design

- **Shape:** Standard macOS rounded-rect (squircle) at all sizes from 16×16 (menu bar) to 1024×1024 (App Store)
- **Background:** Warm off-white `#F5F3EF` (light appearance) / warm dark gray `#2C2A28` (dark appearance). Not pure white, not pure black — the warmth matches the app's `surface.canvas` palette.
- **Foreground element:** The lowercase letters "txt" set in SF Mono Medium, centered. This is the file format itself, presented plainly.
- **Foreground color:** Muted teal `#3A8A7A` — the same `syntax.project` color. This is the one place the brand has a "color." It ties the icon to the syntax highlighting inside the app.
- **Size scaling:**
  - At 1024px and 512px: full "txt" renders clearly
  - At 128px and 64px: "txt" still readable, slightly heavier optical weight
  - At 32px and 16px (menu bar, Finder): simplify to just "t" in the same style. Three letters become indistinct at tiny sizes.

### What the Icon Is Not

- No gradient, no gloss, no 3D shadow under the text
- No colored checkmark or task-related glyph
- No app-name wordmark ("Plain" never appears in the icon itself)
- No border or stroke on the squircle — it should just be the macOS standard icon shape
- Dark appearance uses the `grayDark.900` background, not a darkened version of the light icon

### Generating the Icon

The icon can be constructed in code (no raster assets needed for the basic version):

1. Standard macOS icon squircle at the target size
2. Fill with `#F5F3EF` (light) or `#2C2A28` (dark)
3. Render "txt" in SF Mono Medium, `#3A8A7A`, centered both horizontally and vertically
4. Font size: approximately 40% of the icon height (so ~410pt at 1024px, ~52pt at 128px)
5. Slight negative tracking (-0.5pt per 100pt) to keep the letters optically tight

For the App Store icon, the background should extend to the full bleed area per Apple's icon template.

---

## Menu Bar Icon

- A small glyph displayed in the macOS menu bar (approximately 18×18 points)
- Design: the letter "t" in SF Mono Medium, `text.primary` color (adapts to light/dark menu bar automatically)
- Should NOT be a checkbox, list icon, or other task-app cliché
- When the menu bar extra is active (dropdown open), the icon can use system accent tinting per macOS convention

---

## Wordmark

- "plain" in lowercase, SF Pro Medium, with standard tracking
- Used in: the about box, the onboarding heading (optionally), the website/marketing (if any)
- Color: `text.primary` in the app context; `gray.800` on marketing pages
- The wordmark is always lowercase. Sentence-case "Plain" is used in prose (documentation, menu bar, App Store title) but the visual mark is lowercase.
- No custom ligatures, no icon paired with the wordmark. It stands alone.

---

## About Box

A standard macOS about window, but with personality via restraint.

### Content

```
┌───────────────────────────────────────┐
│                                       │
│              [App Icon]               │
│                                       │
│               plain                   │
│          Version 1.0 (42)             │
│                                       │
│  A todo.txt client for macOS.         │
│  Reads your file. That's it, really.  │
│                                       │
│          © 2026 Dan Munz              │
│                                       │
└───────────────────────────────────────┘
```

- App icon: 64×64
- "plain" wordmark: `type.onboardingHeading` size (24pt), `text.primary`
- Version: `type.statusBar` size (11pt), `text.muted`
- Description: `type.taskBody` (14pt), `text.secondary`. Two short lines. The second line ("Reads your file. That's it, really.") is the one dry-humor beat in the entire app.
- Copyright: `type.statusBar` (11pt), `text.muted`
- Background: `surface.canvas`

---

## Onboarding Flow

Shown on first launch (no file configured) or when the stored file path is inaccessible and no recovery is possible.

### Layout

A centered card on the `surface.canvas` background. No sidebar, no toolbar content (toolbar is present but empty except for the standard window controls).

```
┌──────────────────────────────────────────────┐
│                                              │
│                 [App Icon]                   │
│                  64×64                        │
│                                              │
│     Point Plain at your todo.txt file.       │
│                                              │
│     Todo.txt is a plaintext task format.     │
│     Your tasks live in a .txt file you own.  │
│     Learn more at todotxt.org ↗              │
│                                              │
│     ┌────────────────────────────────────┐   │
│     │   Open an Existing File            │   │
│     └────────────────────────────────────┘   │
│                                              │
│     ┌────────────────────────────────────┐   │
│     │   Create a New File                │   │
│     └────────────────────────────────────┘   │
│                                              │
│          Try with a sample file              │
│                                              │
└──────────────────────────────────────────────┘
```

### Styling

- Card: no visible border or background differentiation — the content floats on `surface.canvas`. The "card" is implicit via the centered layout and generous whitespace.
- Heading: `type.onboardingHeading` (24pt Semibold, -0.3pt tracking), `text.primary`
- Body: `type.onboardingBody` (14pt Regular), `text.secondary`
- "Learn more" link: system accent color, standard link styling
- Primary button ("Open an Existing File"): system accent fill, white text, `radius.md`, 44px height, full width of the content column (max 320px)
- Secondary button ("Create a New File"): outlined — 1px `border.input` border, `text.primary` text, `radius.md`, 44px height
- Tertiary action ("Try with a sample file"): text-only link, `text.muted`, `type.taskMeta` size, centered below the buttons

### Tone

The onboarding should feel like an empty desk — clean, inviting, unhurried. It does not explain what a todo list is. It does not have a carousel of feature screenshots. It does not ask you to create an account. It points you at a file and gets out of the way. Three clicks max to be working.

---

## Empty States

These appear centered in the content area when a filter or view has no matching tasks. They are the most frequent touchpoint for the brand voice.

### Style

- Vertically and horizontally centered in the space between the input bar and status bar
- Text: `type.emptyState` (14pt Regular), `text.muted`
- Single line. No illustration, no icon, no secondary action button.
- Keyboard shortcut references (e.g., "⌘N") can be rendered in `type.taskMeta` size inside a subtle `surface.input` background pill with `radius.sm`.

### Copy

| Filter | Message |
|---|---|
| Inbox (new file) | Nothing here yet. ⌘N to add a task. |
| Inbox (all completed) | Everything's done. Time to archive? |
| Today | Nothing due today. |
| Overdue | No overdue tasks — nice. |
| +project (empty) | No tasks in +{project}. |
| @context (empty) | No @{context} tasks. |
| Search (no match) | No tasks match "{query}". |
| Done (empty archive) | No archived tasks yet. |

The humor is in the *restraint*. "No overdue tasks — nice." is the funniest line in the app, and it works because every other empty state is deadpan. Don't add more humor — the contrast is what makes it land.

---

## File Unavailable State

When the configured file is not accessible (iCloud not synced, external drive disconnected):

### Layout

Same centered layout as onboarding, but with a different message:

```
     Waiting for todo.txt to sync...

     iCloud hasn't delivered the file yet.
     This usually resolves in a moment.

     [ Choose a Different File ]
```

- Heading: `type.onboardingHeading`, `text.primary`
- Body: `type.onboardingBody`, `text.secondary`
- Button: outlined style (not primary), since the user probably just needs to wait
- No spinner or progress indicator — the app isn't doing anything, it's waiting for the filesystem. A spinner would imply the app is the bottleneck.
- If the file becomes available while this screen is showing, transition to the task list with `anim.normal` crossfade.

---

## Conflict Banner Copy

Handled as a component in `component-specs.md`, but the copy is a brand voice surface:

- **External change detected:** "todo.txt changed externally."
- **Done file changed:** "done.txt changed externally."
- **Both files changed:** "todo.txt and done.txt changed externally."

Actions: "Reload" | "Keep Mine" | "View Diff"

No warning icons beyond the triangle. No exclamation marks. No "Warning:" prefix. The banner's existence *is* the warning.

---

## Status Bar Copy

The status bar is a quiet ambient awareness surface. It uses interpuncts (·) as separators:

- `{n} tasks · {n} done this week · {n} overdue`
- If overdue is 0, it still shows "0 overdue" (don't hide it — the zero is reassuring)
- The "done this week" count resets on Monday

---

## Distribution & Marketing (if applicable)

### App Store

- **Title:** Plain
- **Subtitle:** A todo.txt client that stays out of your way.
- **Screenshots:** Use real-looking tasks, not aspirational ones. Tasks like "Call accountant @phone +taxes" and "Pick up cleats @errands", not "Launch startup" or "Change the world."
- **App Store screenshots should show the warm palette, syntax highlighting, and priority badges** — these are the visual differentiators. Include both light and dark mode.

### Website (if built)

- Same warm off-white background (`#F5F3EF`)
- "plain" wordmark at top
- One-sentence positioning: "A todo.txt client for macOS."
- One screenshot of the app with real tasks
- Download link
- Nothing else. The website should load in under a second and have fewer than 200 words.

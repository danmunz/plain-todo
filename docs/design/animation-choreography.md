# Plain — Animation Choreography

Every animated transition in the app, specified precisely enough for implementation. Reference `design-tokens.md` for timing/easing values. All animations respect `accessibilityDisplayShouldReduceMotion`.

---

## Principle

Animation in Plain exists to provide spatial continuity and confirm user actions — never to decorate. Every motion answers the question "what just happened?" or "where did that go?" If removing an animation would leave the user confused, it earns its place. If removing it would go unnoticed, cut it.

Timing target: nothing should last longer than 300ms for primary interactions. The app should feel *snappy*, with motion as a brief acknowledgment rather than a spectacle.

---

## Task Completion Sequence

**Trigger:** User presses Space, clicks the circle, or uses Cmd+D on a focused task.

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Circle receives a brief scale pulse: 100% → 112% → 100% | `anim.completion.circle` (spring, 200ms) |
| 0ms | Circle fill animates from transparent to `status.completed` | same spring |
| 0ms | Small checkmark (SF Symbol `checkmark`, 10pt, `text.inverse`) fades in inside circle | 150ms ease-out |
| 400ms | Strikethrough line begins — a solid 0.5px `text.muted` line that wipes left-to-right across the task text | `anim.completion.strike` (250ms ease-in-out) |
| 400ms | Row opacity begins transitioning to `opacity.completedRow` (0.45) | `anim.completion.dim` (200ms ease-out) |
| 500ms | Undo toast appears at bottom center | `anim.toast.in` (200ms ease-out, fade + translateY 8px) |
| 4500ms | Toast auto-dismisses (if not interacted with) | `anim.toast.out` (150ms ease-in) |

**Reduced motion:** Skip the circle scale pulse, skip the strikethrough wipe. Instantly apply: filled circle, strikethrough, dimmed opacity. Toast still appears but without slide animation (instant opacity).

**Undo (within toast window):** Clicking "Undo" or pressing Cmd+Z reverses the visual state instantly (no reverse animation — that would feel sluggish). Circle empties, strikethrough removed, opacity restored, toast dismisses.

---

## Task Uncomplete

**Trigger:** User presses Space or clicks the circle on a completed task.

**Timeline:** Instant reversal. Circle fill fades out (120ms ease-out), strikethrough removed, opacity restored to 1.0. No toast — uncompleting isn't destructive.

---

## Task Addition

**Trigger:** User presses Return in the input bar or quick-add panel.

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | New row inserted at the bottom of the list | — |
| 0ms | List scrolls to the new row (animated scroll, 200ms) | `anim.normal` |
| 200ms | New row's background pulses: transparent → system accent at 8% → transparent | `anim.pulse` (1000ms ease-in-out, single cycle) |
| 1200ms | Row settles to normal appearance | — |

**Reduced motion:** No scroll animation (instant jump). Background does a 200ms opacity flash from 0.5 to 1.0 instead of the color pulse.

**Input bar:** Clears and remains focused. No animation on the input bar itself.

---

## Task Deletion

**Trigger:** User presses Cmd+Backspace on a focused task (after confirmation if applicable).

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Row fades out: opacity 1.0 → 0.0 | 150ms ease-in |
| 0ms | Row height collapses: current height → 0 | `anim.slow` (300ms ease-in-out) |
| 0ms | Rows below slide up to fill the gap | `anim.slow` |
| 100ms | Undo toast appears | `anim.toast.in` |
| 4100ms | Toast auto-dismisses | `anim.toast.out` |

**Reduced motion:** Instant removal, no collapse animation. Toast appears without slide.

---

## Sidebar Filter Change

**Trigger:** User clicks a sidebar item or uses keyboard to change the active filter.

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Previous sidebar highlight fades out, new highlight fades in | `anim.fast` (120ms) |
| 0ms | Task list crossfades to the new filtered set | `anim.normal` (200ms ease-in-out) |

The crossfade means the old list fades out while the new list fades in simultaneously. This is NOT a slide or a push — it's a dissolve. It should feel like the same list is being re-filtered, not like you're navigating to a new page.

**Reduced motion:** Instant cut, no crossfade.

---

## Sidebar Collapse/Expand

**Trigger:** Cmd+\ or toolbar toggle.

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Sidebar width animates: 220px → 0px (collapse) or 0px → 220px (expand) | `anim.normal` (200ms ease-in-out) |
| 0ms | Content area width expands/contracts to fill | same, synchronized |
| 0ms | Sidebar content fades out/in | 150ms ease-in (fade out starts immediately), ease-out (fade in starts at 100ms) |

The content fade should START before the width animation completes on collapse (so text doesn't visually compress into nothing), and the fade in should LAG behind the width on expand (so you don't see text appearing in a too-narrow space).

**Reduced motion:** Instant show/hide, no width animation.

---

## Scratch Pad Toggle

**Trigger:** Cmd+E or toolbar button.

**Timeline:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Current view (task list or scratch pad) crossfades with incoming view | `anim.normal` (200ms ease-in-out) |

Simple crossfade. The input bar and status bar remain stable (no animation on them — they're anchors). Only the content between them transitions.

**Reduced motion:** Instant cut.

---

## Search Overlay

**Trigger:** Cmd+F.

**Appear:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Overlay starts 8px above its final position, opacity 0 | — |
| 0ms | Overlay translates down 8px to final position + fades to opacity 1.0 | `anim.searchIn` (150ms ease-out) |
| 0ms | Text field receives focus | — |

**Dismiss (Escape — clear filter):**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Overlay translates up 8px + fades to opacity 0 | `anim.searchOut` (120ms ease-in) |
| 0ms | All rows restore to full opacity | `anim.fast` (120ms) |

**Dismiss (Return — keep filter):**
Same as Escape dismiss animation, but rows stay filtered and the search pill appears below the input bar (fade in, `anim.fast`).

**Live filtering during typing:**
As the user types, non-matching rows fade to `opacity.searchDimmed` at `anim.fast` speed. Matching rows stay at full opacity. This transition happens per-keystroke, so it should be fast enough to not feel laggy.

**Reduced motion:** Overlay appears/disappears instantly (no translate). Row opacity changes are still animated at `anim.fast` (this is feedback, not decoration).

---

## Quick-Add Panel

**Trigger:** Ctrl+Opt+T (global hotkey).

**Appear:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Panel starts at 98% scale, opacity 0 | — |
| 0ms | Panel scales to 100% + fades to opacity 1.0 | `anim.quickAdd.in` (150ms ease-out) |

**Dismiss (Return — save, or Escape — cancel):**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Panel fades to opacity 0 (no scale animation on dismiss) | `anim.quickAdd.out` (120ms ease-in) |

**Reduced motion:** Instant appear/disappear.

---

## Drag Reorder

**Trigger:** User initiates a drag on a task row (mouse or keyboard Opt+↑/↓).

**Pickup:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Row lifts: shadow appears (`shadow.drag`), slight scale to 1.02 | 150ms ease-out |
| 0ms | Original position becomes a ghost at `opacity.dragPlaceholder` | `anim.fast` |

**During drag:**
Other rows animate out of the way using `anim.spring` as the dragged row passes over them. The gap-making animation should feel physical — a brief overshoot and settle.

**Drop:**

| Time | What Happens | Token |
|---|---|---|
| 0ms | Row snaps to its new position | `anim.spring` |
| 0ms | Shadow fades out, scale returns to 1.0 | 150ms ease-out |
| 0ms | Ghost disappears | instant |

**Keyboard reorder (Opt+↑/↓):**
The row and its neighbor swap positions with `anim.spring`. No shadow or scale — just the positional swap with a spring feel.

**Reduced motion:** Instant position changes, no spring. Shadow still appears on mouse drag (it's a spatial cue, not decorative motion).

---

## Hover State Transitions

**Row hover:**
- Background: transparent → `surface.hover` at `anim.fast` (120ms ease-out)
- "···" menu: opacity 0 → `opacity.hoverMenu` (0.7) at `anim.fast`

**Row unhover:**
- Reverse at same speed

**Sidebar item hover:**
- Same pattern as row hover

**Completion circle hover (within row):**
- Circle stroke: current color → one step darker at `anim.fast`

---

## Toast Lifecycle

All toasts (completion, deletion, any future transient feedback) follow the same lifecycle:

1. **Appear:** `anim.toast.in` — fade in + translate up 8px from below final position
2. **Linger:** `anim.toast.linger` (4000ms) — visible, interactive
3. **Auto-dismiss:** `anim.toast.out` — fade out + translate down 4px
4. **Manual dismiss** (user clicks action or presses Cmd+Z): instant hide, no animation

If a second toast triggers while one is active (e.g., user completes two tasks in quick succession), the first toast is immediately replaced (instant cut) and the new toast starts its linger timer fresh.

---

## Window/Session Restore

On launch, no animated transitions. The window appears at its saved position with the saved filter, sort, and scroll position already applied. The app should feel like it was never closed — animation on launch would undermine that.

---

## Inline Edit Transition

**Trigger:** Return on a focused row, or click on task text.

**Enter edit mode:**
- The task text becomes an editable text field (in-place, same font/size/position)
- The row's left edge bar changes to system accent (if not already selected)
- A subtle `surface.hover` background appears if not already present
- Transition: `anim.fast` for any background/border changes. The text transformation itself should be instant — don't animate the cursor appearing.

**Exit edit mode (Return to save, Escape to cancel):**
- Text field reverts to styled attributed string display
- Background/border revert at `anim.fast`
- If the edit changed the task, syntax highlighting re-applies to the new text immediately

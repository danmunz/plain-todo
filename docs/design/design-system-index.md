# Plain — Design System Index

This directory contains the visual design specification for Plain's visual revamp. These docs are intended to be consumed by a coding agent implementing the changes against the existing SwiftUI codebase.

---

## Reading Order

1. **`design-tokens.md`** — Read first. Every color, font size, spacing value, shadow, radius, and animation timing is defined here. All other docs reference these tokens by name.

2. **`visual-audit.md`** — Read second. This is the gap analysis between the current app state and the target. It contains a prioritized tier system (Tier 1 → Tier 4) that dictates implementation order. **Start with Tier 1.**

3. **`component-specs.md`** — Reference as needed. Detailed per-component specs with exact measurements, layout diagrams, and state tables. Consult this when implementing a specific component.

4. **`animation-choreography.md`** — Reference as needed. Every animated transition with timelines, easing curves, and reduced-motion fallbacks. Consult this when adding motion to any interaction.

5. **`brand-and-icon.md`** — Reference for app icon, about box, onboarding, empty states, and voice/copy decisions.

---

## Design Direction (Summary)

Plain's visual identity is **warm neutral** — a subtle warm tint on all surfaces (off-white in light mode, warm dark gray in dark mode), with color entering only through two channels:

- **Syntax highlighting:** teal for +projects, violet for @contexts — these are the brand's visual signature.
- **Priority coding:** red (A), amber (B), blue (C) — functional color that aids scanning.

Everything else — backgrounds, borders, text — uses the warm gray scale. No signature-colored sidebar. No branded accent color. The personality comes from the warmth of the neutrals, the quality of the typography (weight contrast, allcaps section headers, generous sizing), and the restraint of the color palette.

**Reference apps for feel:** iA Writer (warmth, typography focus), Things 3 (interaction quality, spatial clarity), Bear (warm neutrals, native feel).

**Anti-references:** Todoist (too much color), Notion (too web-app), stock SwiftUI (too cold).

---

## Key Constraint

Plain is a macOS-native SwiftUI app. All implementations should:

- Use SwiftUI views and modifiers where possible
- Bridge to AppKit only where SwiftUI is insufficient (NSTextView for scratch pad, NSPanel for quick-add)
- Respect system appearance (light/dark), system accent color, and accessibility settings (reduced motion, increased contrast, VoiceOver)
- Feel like a native macOS citizen — standard window chrome, standard toolbar, standard menus. The personality lives in the content area, not in custom window decorations.

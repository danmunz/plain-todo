# Plain

Plain is a native macOS todo.txt client. The repo now supports both a SwiftPM bootstrap path and an Xcode-native app project generated from XcodeGen.

## Current Shape

- `PlainCore` contains the parser, serializer, mutation layer, and coordinated file store.
- `PlainApp` is a SwiftUI macOS app shell with onboarding, last-file and last-filter session restore for normal launches, per-view persisted sort modes, grouped sorted task views, a transient Cmd+F search overlay with live filtering and match highlighting, natural-language due-date preview in the add bar, automatic creation-date insertion for new tasks, inline raw-line editing, a scratch-pad raw file toggle, a global quick-add panel on `Ctrl+Opt+T`, an optional menu bar extra with live counts and quick actions, custom `plain://` deep links into filtered views, keyboard selection, undo-backed add, complete, reprioritize, edit, delete, keyboard reorder, drag reorder, and archive flows, plus a read-only `done.txt` view, archive-behavior, creation-date, show-completed, and menu-bar preferences, and non-modal external-change conflict handling with reload, keep-mine, and view-diff resolution.
- `PlainWidgetExtension` is a WidgetKit extension bootstrap that renders a shared snapshot contract and deep-links back into filtered views.
- `PlainCoreTests`, `PlainAppTests`, and `PlainUITests` cover parser fidelity, coordinated file access, dual-file archive transactions, external-change handling, shell-model undo and selection behavior, and a basic app launch smoke path.

## Toolchain

The primary development path is now the generated Xcode project.

- `project.yml` is the source of truth for the Xcode project.
- `xcodegen generate` refreshes `Plain.xcodeproj` after target or file-layout changes.
- `xcodebuild` is the primary validation path.
- `swift build` and `swift test` remain useful for fast core-only validation.

## Build

```bash
xcodegen generate
xcodebuild -project Plain.xcodeproj -scheme PlainApp -destination 'platform=macOS' build
```

## Run

Run the app from Xcode:

```bash
open Plain.xcodeproj
```

Then run the `PlainApp` scheme. To start against a real file, add a launch argument in the scheme:

```bash
--todo-file ~/path/to/todo.txt
```

Without an explicit launch argument, the app restores the last writable `todo.txt` file and last active sidebar filter from the previous session. Explicit launch arguments and UI-testing launches bypass that restore state.

Deep links are also supported via `plain://`:

- `plain://inbox`
- `plain://today`
- `plain://overdue`
- `plain://done`
- `plain://project/Some%20Project`
- `plain://context/Some%20Context`

You can pass a launch deep link as `--deep-link plain://today`, `--deep-link=plain://today`, or as a standalone launch argument like `plain://today`.

The SwiftPM bootstrap is still available:

```bash
swift run PlainApp
swift run PlainApp ~/path/to/todo.txt
```

## Test

```bash
xcodebuild -project Plain.xcodeproj -scheme PlainApp -destination 'platform=macOS' test
```

For faster core-only validation:

```bash
swift test
```

## Download & Install

Grab the latest `.zip` from [Releases](../../releases). Unzip and move `Plain.app` to your Applications folder.

Since the app is unsigned (no Apple Developer Program membership), macOS Gatekeeper will block the first launch. To open it:

1. Right-click (or Control-click) `Plain.app` → **Open** → click **Open** in the dialog, or
2. Run in Terminal: `xattr -cr /Applications/Plain.app`

After the first launch, macOS remembers your choice and opens it normally.

## Releasing

Push a version tag to trigger a GitHub Actions build that archives and publishes:

```bash
# bump version in Sources/PlainApp/Info.plist, then:
git tag v0.1.0
git push origin v0.1.0
```

The workflow archives the app unsigned and attaches `Plain-vX.Y.Z-macOS.zip` to the GitHub Release.

## Status

v1 feature-complete:

- PlainCore-first architecture with one coordinated read/write pipeline
- Session restore (last file, sidebar filter, window frame, sort modes)
- Full editing: inline raw-line edit, scratch-pad, quick-add panel, add bar with natural-language due-date preview
- Keyboard-first: navigation, J/K, selection, multi-select, reorder, complete, delete, reprioritize, undo/redo
- Optional menu bar extra with live counts and quick actions
- Grouped/sorted task views, Cmd+F live search, sidebar smart filters
- Coordinated archive-to-`done.txt` with read-only Done view
- External-change conflict handling with side-by-side diff, reload, and keep-mine resolution
- WidgetKit extension with deep links back into filtered views
- Full preferences (General/Appearance/Shortcuts/Advanced)
- Accessibility: VoiceOver labels, reduced-motion support, high-contrast token adaptation
- UI regression tests for keyboard editing flows
- No database or hidden persistence
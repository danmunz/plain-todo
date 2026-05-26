# Plain

Plain is a native macOS todo.txt client. The repo now supports both a SwiftPM bootstrap path and an Xcode-native app project generated from XcodeGen.

## Current Shape

- `PlainCore` contains the parser, serializer, mutation layer, and coordinated file store.
- `PlainApp` is a SwiftUI macOS app shell with onboarding, persisted file selection, sidebar-derived filters, per-view persisted sort modes, inline raw-line editing, keyboard selection, undo-backed add, complete, reprioritize, edit, delete, reorder, and archive flows, plus a read-only `done.txt` view, archive-behavior preferences, and non-modal external-change conflict handling.
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

## Status

The current bootstrap has working foundations but is not yet v1 complete:

- PlainCore-first architecture
- one coordinated read and write pipeline
- sidebar-derived filters, per-view persisted sort modes, and persisted file choice
- inline raw-line editing, keyboard row selection, UndoManager-backed destructive edits, reorder, coordinated archive-to-`done.txt`, archive-behavior preferences, and reload-or-keep-mine conflict handling for external file changes
- Xcode-native app, unit-test, and UI-test path
- no database or hidden persistence
- no widget, menu bar, quick-add, diff view, search overlay, bulk actions, or scratch pad yet
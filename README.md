# Plain

Plain is a native macOS todo.txt client. This repo is currently bootstrapped as a Swift package so work can continue before a full Xcode app project is available.

## Current Shape

- `PlainCore` contains the parser, serializer, mutation layer, and coordinated file store.
- `PlainApp` is a SwiftUI bootstrap executable with onboarding, persisted file selection, sidebar-derived filters, and a narrow editable path for add, complete, reprioritize, and delete.
- `PlainCoreTests` covers parser fidelity, malformed line preservation, newline handling, mutation behavior, coordinated reads, and coordinated writes.

## Toolchain Constraint

This repository is intentionally set up for the Swift 6 command line toolchain only.

- `swift build` and `swift test` are the supported validation commands today.
- `xcodebuild` and a normal `.xcodeproj` or `.xcworkspace` app target are not available until full Xcode is installed.
- The SwiftUI shell is a bootstrap executable, not the final app-bundle, signing, widget, or extension story.

## Build

```bash
swift build
swift build --product PlainApp
```

## Run

Launch the bootstrap shell with the bundled sample snapshot:

```bash
swift run PlainApp
```

Or point it at a real todo.txt path:

```bash
swift run PlainApp ~/path/to/todo.txt
```

## Test

```bash
swift test
```

## Status

The current bootstrap has working foundations but is not yet v1 complete:

- PlainCore-first architecture
- one coordinated read and write pipeline
- sidebar-derived filters and persisted file choice
- minimal editable shell actions: add, complete, reprioritize, delete
- no database or hidden persistence
- no archive flow, widget, menu bar, quick-add, or scratch pad yet
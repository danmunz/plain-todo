# Plain Implementation Plan

## Status

This repo is no longer docs-only. It now has a SwiftPM bootstrap, an XcodeGen-backed `Plain.xcodeproj`, `PlainCore`, a SwiftUI `PlainApp` shell, parser and serializer coverage, coordinated read and write support, inline raw-line editing, keyboard row selection, UndoManager-backed destructive edits, keyboard and drag reorder, coordinated archive-to-`done.txt`, a read-only Done view, archive-behavior, creation-date, and show-completed preferences, persisted per-view sort modes, basic last-file and last-filter session restore, grouped sorted task views, a transient Cmd+F search overlay with live filtering, natural-language due-date parsing and preview in the add bar, explicit external-change conflict handling with reload and keep-mine flows, and working app, unit, and UI smoke tests. Widgets, app extensions, richer diff tooling, and secondary surfaces remain open. The plan below remains the dependency order for the remaining work.

## Recommended Stack

- Swift 6
- SwiftUI for the main app shell
- AppKit bridges where SwiftUI is weak for v1:
  - `NSTextView` with TextKit 2 for scratch pad mode
  - `NSPanel` for the global quick-add panel
  - `NSStatusItem` or `MenuBarExtra` for menu bar presence
- Foundation, AppKit, SwiftUI, WidgetKit, AppIntents, OSLog, XCTest
- `UserDefaults` for preferences and session restore
- App Group for widget-shared configuration if the widget remains in v1
- No database, no index, no hidden persistence layer

## Proposed Target Structure

- `PlainApp`
  - macOS app target
  - window lifecycle, onboarding, preferences, menu bar, quick-add, deep links
- `PlainCore`
  - shared module for parser, serializer, filtering, search projection, archive planning, and coordinated file access abstractions
- `PlainWidgetExtension`
  - WidgetKit target backed by `PlainCore`
- `PlainCoreTests`
  - parser, serializer, mutation, archive, and performance tests
- `PlainAppTests`
  - file coordination, session restore, preferences, undo wiring
- `PlainUITests`
  - onboarding, keyboard flows, inline edit, archive, search, scratch pad, accessibility smoke

## Architecture Boundaries

### PlainCore Model

- `RawTodoLine`
- `TodoTask`
- `TodoFileSnapshot`
- `LineIdentity`
- `ParsedToken`
- `StatsSnapshot`

Responsibilities:

- represent parsed tasks without losing raw text
- keep transient identity out of the file format
- support both `todo.txt` and `done.txt`

### PlainCore Parsing

- `TodoParser`
- `TodoSerializer`
- `LineTokenizer`
- `TaskMutation`
- `MutationPlan`
- `DatePhraseParser`

Responsibilities:

- round-trip fidelity
- preserve unknown key:value pairs and malformed lines
- preserve newline style and trailing newline
- limit natural language parsing to `due:` date extraction only

### PlainCore Query

- `TaskFilter`
- `FilterKey`
- `TaskSortMode`
- `TaskGroup`
- `ProjectedTaskList`
- `TaskSearchQuery`

Responsibilities:

- derive sidebar sections, smart filters, counts, grouping, search results, and status stats
- preserve file order as a first-class sort mode

### PlainCore File Access

- `CoordinatedTodoStore`
- `PresentedTodoFile`
- `FileVersionSnapshot`
- `WriteTransaction`
- `ConflictState`
- `ConflictResolution`

Responsibilities:

- read and write through `NSFileCoordinator`
- observe changes with `NSFilePresenter`
- model external-change and conflict state without silent overwrite

### PlainApp State And Services

- `AppSessionState`
- `TaskListState`
- `SelectionState`
- `InlineEditState`
- `ScratchPadState`
- `SearchOverlayState`
- `PreferencesState`
- `UndoCoordinator`
- `ArchiveService`
- `QuickAddService`
- `SessionRestoreStore`
- `SortPreferenceStore`

Responsibilities:

- keep one canonical UI state tree
- route all mutations through the shared persistence layer
- restore window state, active filter, sort, and scroll anchor

## Execution Phases

### Phase 0. Bootstrap

Deliverables:

- create the Xcode project and targets
- set up shared fixtures and test bundles
- configure entitlements, logging, and CI build/test path

Quality gate:

- a clean clone builds and launches a placeholder app window
- shared-core tests run headless
- the project layout can absorb a widget target later without refactor

### Phase 1. Parser And Safe File Access

Deliverables:

- parse and serialize todo.txt with line-preserving behavior
- support add, complete, reprioritize, delete, reorder, and archive mutation primitives
- preserve malformed lines, unknown metadata, newline style, and trailing newline
- implement coordinated read/write and external change detection

Quality gate:

- untouched lines are byte-identical after round-trip
- touched lines only change in the intended textual region
- large fixtures parse within the target budget
- simulated external writes produce deterministic conflict state

### Phase 2. Read-Only App Shell

Deliverables:

- first-launch open or create flow
- single-window shell with toolbar, sidebar, task list, and status bar
- discovered `+projects`, `@contexts`, and smart filters
- done.txt count and read-only done view
- initial session restore scaffolding

Quality gate:

- the app opens a real file and renders it without writing anything
- large lists remain responsive
- derived counts and view state match fixture expectations

### Phase 3. Core Editing And Keyboard Workflows

Deliverables:

- persistent add-task input
- inline raw-line editing
- completion, deletion, reprioritization, and reorder
- keyboard navigation and selection
- undo and redo for all destructive operations

Quality gate:

- the primary flows work without the mouse
- every destructive action is undoable
- all writes flow through the same coordinated store

Current progress note:

- the shell now supports coordinated add, complete, reprioritize, inline edit, and delete flows through one write path
- keyboard selection and UndoManager-backed undo or redo are implemented for the current shell
- completed tasks can now be archived into `done.txt` through a coordinated dual-file transaction, and the Done sidebar view is backed by the archive file
- external todo and done file changes are now observed explicitly, with non-modal reload and keep-mine conflict handling that avoids clobbering active drafts
- reorder is implemented in the inbox via keyboard, menu, and drag actions, each task view remembers its own display sort mode in app state without mutating file order, normal launches restore the last writable file plus a validated sidebar filter, completed rows stay visible by default until archived with a persisted hide toggle for list cleanup, sorted views render lightweight grouping headers, Cmd+F presents a transient live-search overlay that composes with sidebar filters, and the add bar previews and applies supported due-date phrases with automatic creation dates controlled by preferences
- richer diff tooling and broader regression coverage for end-to-end keyboard editing remain open

### Phase 4. Advanced File Workflows

Deliverables:

- archive completed tasks to done.txt
- scratch pad mode
- conflict banner and resolution actions
- iCloud unavailable and waiting states
- preferences that affect write behavior

Quality gate:

- archive updates both files atomically
- scratch pad and structured mode stay consistent
- external changes never silently clobber in-progress edits

### Phase 5. Secondary Surfaces

Deliverables:

- global quick-add panel
- optional menu bar mode
- widget extension and deep links

Quality gate:

- each surface uses the same write path and source of truth
- quick-add works while the main window is hidden
- widget output matches app-derived task data

### Phase 6. Release Hardening

Deliverables:

- accessibility labels and VoiceOver polish
- reduced-motion and high-contrast behavior
- performance tuning and regression coverage

Quality gate:

- large-file performance, accessibility, and iCloud conflict checks pass on real-world files

## Initial Coding Slice

The first implementation pass should not start with UI polish. It should prove the storage model.

Build first:

- `PlainCore` model types
- `TodoParser`
- `TodoSerializer`
- a minimal mutation layer for add, toggle complete, and set or remove priority
- `CoordinatedTodoStore`

Pair that with the smallest possible UI:

- onboarding file picker
- a single main window
- a read-only sidebar
- a read-only task list fed by the real file

This slice is complete when a real `todo.txt` can be opened from local disk or iCloud Drive, rendered accurately, reparsed after external edits, and no-op saved with zero diff.

## Backlog By Epic

### Epic A. Foundation

- create the app project and targets
- create fixture files for small, malformed, mixed-newline, and large task sets
- define shared model and state types
- add CI for build and test

### Epic B. Parser And Integrity

- line splitting with newline preservation
- completion, date, priority, project, context, and key:value parsing
- byte-identical write-back for untouched lines
- atomic writes and replace behavior
- coordinated read and write wrapper
- external-change detection and conflict state machine

### Epic C. Read-Only Shell

- onboarding flow
- main window shell
- sidebar sections and counts
- status bar stats
- sort, grouping, search, and filter state model
- per-filter sort memory and basic session restore

### Epic D. Editing And Keyboard UX

- persistent input bar with append-to-bottom behavior
- focused task navigation and selection
- inline raw-line editing with save and cancel behavior
- complete, delete, reprioritize, and reorder flows
- multi-select and bulk operations after single-item flows stabilize
- `UndoManager` integration

### Epic E. Advanced File Workflows

- archive confirmation and dual-file archive transaction
- read-only done view
- scratch pad mode with parse-on-exit rebuild
- conflict banner with reload and keep-mine flows
- file-unavailable handling
- preferences and backup option

### Epic F. Secondary Surfaces And Polish

- global quick-add panel
- menu bar dropdown
- widget extension
- deep links into filtered app views
- accessibility pass
- performance instrumentation and regression fixtures

## Validation Strategy

### Unit Tests

- parser fixtures
- round-trip fidelity
- malformed-line survival
- newline preservation
- filter, sort, grouping, and session reducers
- mutation builders
- archive planning

### Integration Tests

- temp-file atomic write tests
- coordinated read and write tests
- simulated external file change scenarios
- dual-file archive transactions
- scratch pad parse-rebuild behavior

### UI Tests

- onboarding and file open
- sidebar selection and search overlay
- keyboard navigation
- inline edit save and cancel
- undo and redo
- archive flow
- scratch pad toggle

### Manual Checks

- open real files from standard folders and iCloud Drive
- verify no-op open and save produce no file diff
- run a realistic keyboard-only triage session
- verify reduced motion and VoiceOver behavior
- verify widget and quick-add after the main app is stable

## Definition Of Done For v1

- the app opens or creates a single todo file and optional done file
- parser and writer tests prove file fidelity and unknown syntax preservation
- all writes are coordinated and atomic
- external changes never silently overwrite in-progress edits
- core keyboard-first flows are complete
- scratch pad, done view, per-filter sort memory, session restore, quick-add, menu bar mode, and widget work against the same underlying file model
- accessibility and performance targets pass both automated and manual checks

## Do Not Start Too Early

- do not start the widget, menu bar mode, or quick-add before there is one proven write pipeline
- do not start a rich diff UI before the simpler conflict flow is stable
- do not spend early time on icon polish or animation tuning while file safety and inline editing remain unresolved
- do not introduce a database or index to simplify query behavior

## Open Technical Decisions

- minimum supported macOS version
- distribution model: App Store, direct distribution, or both
- task list implementation base: pure SwiftUI list stack or AppKit-backed list
- scratch pad implementation: `TextEditor` or bridged `NSTextView`
- widget file-access model: direct file resolution or app-published shared snapshot
- global hotkey implementation approach and dependency policy
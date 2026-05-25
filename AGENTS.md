# AGENTS.md — Plain Development Guidelines

## Project Context

- This repo is for **Plain**, a native macOS todo.txt client.
- The current source of truth for product behavior is [docs/plain-spec.md](/Users/danmunz/projects/plain-todo/docs/plain-spec.md).
- The current source of truth for implementation sequencing is [docs/implementation-plan.md](/Users/danmunz/projects/plain-todo/docs/implementation-plan.md).
- Core engineering constraints are not optional:
  - preserve todo.txt round-trip fidelity
  - use `NSFileCoordinator` and `NSFilePresenter` for coordinated file access
  - keep one write pipeline for the app, quick-add surface, menu bar surface, and widget
  - avoid hidden persistence layers such as databases or index files

## Commit Discipline

- **Atomic commits**: each commit should represent one self-contained change. Do not mix parser work, UI work, and documentation churn in the same commit unless they are inseparable.
- **Descriptive messages**: use clear, imperative commit messages such as `Add todo.txt round-trip fixtures` or `Implement coordinated file reads`.
- **Branches for non-trivial work**: create a feature or fix branch for meaningful changes. Use descriptive names such as `feat/parser-roundtrip`, `feat/main-window-shell`, or `fix/conflict-reload-state`. Push the branch and open a pull request. Do not merge into `main` automatically.
- **Do not commit speculative architecture**: if a decision is still open in the implementation plan, settle it explicitly before committing a large slice that depends on it.
- **No commits to `main` without validation**: every change intended for `main` must include the narrowest relevant validation that exists for that slice. For code changes, that means passing tests once the Xcode project exists. For the current docs-only stage, keep untested changes limited to documentation and planning artifacts.

## Spec And Planning Maintenance

- Keep [docs/plain-spec.md](/Users/danmunz/projects/plain-todo/docs/plain-spec.md) as the product contract. If implementation reveals a real mismatch, update the spec or record the deviation explicitly.
- Keep [docs/implementation-plan.md](/Users/danmunz/projects/plain-todo/docs/implementation-plan.md) current when execution phases, milestones, or major technical decisions change.
- Do not quietly drift from the planned order of operations. The parser, serializer, and coordinated file access come before advanced UI surfaces.

## README Maintenance

- **README must stay current**: any PR that changes setup steps, build steps, testing commands, architecture expectations, or user-facing behavior must update `README.md` in the same change.
- If `README.md` does not exist yet and a change introduces runnable setup or developer workflow, create it as part of that change.
- Do not leave setup knowledge trapped in PR descriptions or commit messages.

## Testing

- Prefer Apple-native test tooling for this repo:
  - unit and integration tests in `XCTest` or `Swift Testing`
  - UI flows in `XCUITest`
- Expected test targets:
  - `PlainCoreTests`
  - `PlainAppTests`
  - `PlainUITests`
- Prioritize test coverage for the highest-risk behavior:
  - parser and serializer round-trip fidelity
  - newline and trailing-newline preservation
  - malformed-line preservation
  - coordinated file reads and writes
  - archive transactions across `todo.txt` and `done.txt`
  - conflict handling during external file changes
  - keyboard-first core flows
- Once the Xcode project is scaffolded, run the repo’s documented build and test commands before merging. The expected default should be an `xcodebuild test` path for the macOS app scheme.
- Do not merge parser or file-access changes without focused fixtures and regression coverage.

## Release And Distribution

- No deployment pipeline is defined yet for this repo.
- Do not assume GitHub Pages, web hosting, or any web deployment model.
- Distribution is still an open decision. Until that is settled, keep release automation assumptions out of routine feature work.
- When release automation is added, it must at minimum:
  - build the macOS app cleanly
  - run the test suite before shipping
  - document the signing, notarization, and distribution path clearly

## Practical Guardrails

- Do not introduce a database, sync backend, or proprietary storage layer.
- Do not build the widget, menu bar mode, or global quick-add on a separate persistence path.
- Do not start polish-heavy UI work before the storage and coordination layer is proven.
- Prefer small, reviewable slices: core model, parser, coordinated store, read-only shell, then editable workflows.
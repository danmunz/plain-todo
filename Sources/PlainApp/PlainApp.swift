import Combine
import PlainCore
import SwiftUI
import UniformTypeIdentifiers
#if canImport(WidgetKit)
import WidgetKit
#endif

private enum FocusField: Hashable {
    case newTask
    case inlineEdit
    case search
}

@main
struct PlainApp: App {
    @StateObject private var preferences: PreferencesStore
    @StateObject private var model: PlainShellModel
    @StateObject private var quickAddController: QuickAddPanelController
    private let isRunningTests: Bool

    init() {
        let preferences = PreferencesStore()
        let model = PlainShellModel(preferences: preferences)
        let quickAddController = QuickAddPanelController(model: model)
        _preferences = StateObject(wrappedValue: preferences)
        _model = StateObject(wrappedValue: model)
        _quickAddController = StateObject(wrappedValue: quickAddController)
        self.isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        PlainAppScenes(
            preferences: preferences,
            model: model,
            quickAddController: quickAddController,
            isRunningTests: isRunningTests
        )
    }
}

struct PlainShellView: View {
    @ObservedObject private var model: PlainShellModel
    @Environment(\.undoManager) private var undoManager
    @State private var isFileImporterPresented = false
    @State private var isArchiveConfirmationPresented = false
    @State private var isSearchPresented = false
    @State private var newTaskText = ""
    @State private var searchText = ""
    @State private var editingRowID: LineIdentity?
    @State private var editingRawText = ""
    @State private var hoveredRowID: LineIdentity?
    @State private var scratchPadText = ""
    @FocusState private var focusedField: FocusField?

    init(model: PlainShellModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Section("Smart Filters") {
                    SidebarRow(title: "Inbox", count: model.inboxCount)
                        .tag(SidebarSelection.inbox)
                    SidebarRow(title: "Today", count: model.todayCount)
                        .tag(SidebarSelection.today)
                    SidebarRow(title: "Overdue", count: model.overdueCount)
                        .tag(SidebarSelection.overdue)
                    SidebarRow(title: "Done", count: model.doneCount)
                        .tag(SidebarSelection.done)
                }

                if !model.projectCounts.isEmpty {
                    Section("+projects") {
                        ForEach(model.projectCounts, id: \.name) { project in
                            SidebarRow(title: "+\(project.name)", count: project.count)
                                .tag(SidebarSelection.project(project.name))
                        }
                    }
                }

                if !model.contextCounts.isEmpty {
                    Section("@contexts") {
                        ForEach(model.contextCounts, id: \.name) { context in
                            SidebarRow(title: "@\(context.name)", count: context.count)
                                .tag(SidebarSelection.context(context.name))
                        }
                    }
                }
            }
            .accessibilityIdentifier("plain.sidebar")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            Group {
                if model.snapshot == nil, model.loadError == nil {
                    onboardingView
                } else if let loadError = model.loadError {
                    PlaceholderCard(
                        title: model.isWaitingForICloud ? "Downloading from iCloud…" : "Unable to load todo.txt",
                        systemImage: model.isWaitingForICloud ? "icloud.and.arrow.down" : "exclamationmark.triangle",
                        message: loadError,
                        primaryActionTitle: model.isWaitingForICloud ? nil : "Open an existing file",
                        primaryAction: model.isWaitingForICloud ? nil : { isFileImporterPresented = true },
                        secondaryActionTitle: model.isWaitingForICloud ? nil : "Use bundled sample",
                        secondaryAction: model.isWaitingForICloud ? nil : { model.loadBundledSample() }
                    )
                } else {
                    detailView
                }
            }
        }
        .frame(minWidth: 760, minHeight: 440)
        .onChange(of: newTaskText) { _, updatedValue in
            model.updateDraftState(newTaskText: updatedValue, editingRowID: editingRowID, editingRawText: editingRawText)
        }
        .onChange(of: editingRowID) { _, updatedValue in
            model.updateDraftState(newTaskText: newTaskText, editingRowID: updatedValue, editingRawText: editingRawText)
        }
        .onChange(of: editingRawText) { _, updatedValue in
            model.updateDraftState(newTaskText: newTaskText, editingRowID: editingRowID, editingRawText: updatedValue)
        }
        .onChange(of: scratchPadText) { _, updatedValue in
            model.updateScratchPadDraft(updatedValue)
        }
        .onChange(of: searchText) { _, updatedValue in
            model.setSearchQuery(updatedValue)
        }
        .onChange(of: model.draftResetToken) { _, _ in
            resetDraftUI()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Open") {
                    isFileImporterPresented = true
                }

                Button("Use Sample") {
                    model.loadBundledSample()
                }

                Button("New Task") {
                    focusedField = .newTask
                }
                .keyboardShortcut("n")

                Button("Toggle Complete") {
                    let ids = model.selectedRowIDs
                    guard !ids.isEmpty else { return }
                    for id in ids {
                        model.toggleCompletion(lineIdentity: id, undoManager: undoManager)
                    }
                }
                .keyboardShortcut("d")

                Button("Archive Completed") {
                    isArchiveConfirmationPresented = true
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])
                .disabled(!model.isEditable || model.archivableCompletedTaskCount == 0)

                Button(model.isScratchPadPresented ? "Save & Return" : "Scratch Pad") {
                    toggleScratchPad()
                }
                .keyboardShortcut("e")
                .disabled(!model.canToggleScratchPad)

                Picker("Sort", selection: Binding(get: { model.sortMode }, set: { model.setSortMode($0) })) {
                    ForEach(TaskSortMode.allCases) { sortMode in
                        Text(sortMode.title).tag(sortMode)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.selection == .done)
            }
        }
        .alert(
            "Archive \(model.archivableCompletedTaskCount) completed tasks to done.txt?",
            isPresented: $isArchiveConfirmationPresented
        ) {
            Button("Archive") {
                model.archiveCompletedTasks(undoManager: undoManager)
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    return
                }
                model.open(url: url)
            case let .failure(error):
                model.present(error: error)
            }
        }
        .task {
            model.loadInitialSnapshotIfNeeded()
        }
        .overlay(alignment: .top) {
            if isSearchPresented {
                searchOverlay
                    .padding(.top, 76)
            }
        }
        .sheet(
            item: Binding(
                get: { model.presentedConflictDiff },
                set: { _ in model.dismissConflictDiff() }
            )
        ) { diff in
            ConflictDiffSheet(
                diff: diff,
                reloadAction: { model.reloadFromConflictDiff() },
                keepMineAction: { model.keepMineFromConflictDiff() },
                closeAction: { model.dismissConflictDiff() }
            )
        }
    }

    private var onboardingView: some View {
        PlaceholderCard(
            title: "Point Plain at your todo.txt file.",
            systemImage: "text.page",
            message: "Start with an existing todo.txt file, or load the bundled sample while the bootstrap shell is still read-only.",
            primaryActionTitle: "Open an existing file",
            primaryAction: { isFileImporterPresented = true },
            primaryActionAccessibilityIdentifier: "plain.onboarding.open",
            secondaryActionTitle: "Use bundled sample",
            secondaryAction: { model.loadBundledSample() },
            secondaryActionAccessibilityIdentifier: "plain.onboarding.sample"
        )
        .accessibilityIdentifier("plain.onboarding")
    }

    private var addTaskPreview: DatePhrasePreview? {
        guard let previewText = model.previewTextForNewTask(newTaskText),
              let preview = DatePhraseParser.preview(for: newTaskText)
        else {
            return nil
        }

        return DatePhrasePreview(
            sourcePhrase: preview.sourcePhrase,
            dueDate: preview.dueDate,
            transformedText: previewText
        )
    }

    private var detailView: some View {
        Group {
            if model.isScratchPadPresented {
                scratchPadDetailView
            } else if model.selection == .done {
                archiveDetailView
            } else {
                activeTasksDetailView
            }
        }
    }

    private var activeTasksDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Plain")
                    .font(.largeTitle.weight(.semibold))
                Text(model.sourceDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let transientError = model.transientError {
                    Text(transientError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if model.hasExternalTodoConflict {
                conflictBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            HStack(spacing: 12) {
                TextField("Add a task...", text: $newTaskText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .newTask)
                    .disabled(!model.isEditable)
                    .accessibilityIdentifier("plain.add.textField")
                    .accessibilityLabel("Add a task")
                    .accessibilityHint("Type a task and press Return to add it")
                    .onSubmit {
                        guard !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }

                        model.addTask(rawText: newTaskText, undoManager: undoManager)
                        newTaskText = ""
                    }

                Button("Add") {
                    guard !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }

                    model.addTask(rawText: newTaskText, undoManager: undoManager)
                    newTaskText = ""
                }
                .disabled(!model.isEditable || newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("plain.add.button")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if let addTaskPreview {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(addTaskPreview.transformedText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            if model.hasActiveSearch && !isSearchPresented {
                searchFilterPill
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }

            if !model.isEditable {
                Text("Editing is disabled for the bundled sample. Open a writable todo.txt file to try the write path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            List(selection: $model.selectedRowIDs) {
                if model.canDragReorder, let flatGroup = model.visibleGroups.first {
                    ForEach(flatGroup.rows) { row in
                        activeTaskRow(row)
                    }
                    .onMove { offsets, destination in
                        model.moveVisibleRows(fromOffsets: offsets, toOffset: destination, undoManager: undoManager)
                    }
                } else {
                    ForEach(model.visibleGroups) { group in
                        if let title = group.title {
                            Section {
                                ForEach(group.rows) { row in
                                    activeTaskRow(row)
                                }
                            } header: {
                                GroupHeader(title: title)
                            }
                        } else {
                            ForEach(group.rows) { row in
                                activeTaskRow(row)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .onMoveCommand { direction in
                switch direction {
                case .down:
                    model.moveSelection(by: 1)
                case .up:
                    model.moveSelection(by: -1)
                default:
                    break
                }
            }
            .onKeyPress(characters: .init(charactersIn: "jk")) { press in
                guard focusedField == nil, editingRowID == nil else {
                    return .ignored
                }
                switch press.characters {
                case "j":
                    model.moveSelection(by: 1)
                    return .handled
                case "k":
                    model.moveSelection(by: -1)
                    return .handled
                default:
                    return .ignored
                }
            }
            .onDeleteCommand {
                let ids = model.selectedRowIDs
                guard !ids.isEmpty else { return }
                for id in ids {
                    model.deleteRow(lineIdentity: id, undoManager: undoManager)
                }
            }
            .onExitCommand {
                if isSearchPresented || focusedField == .search {
                    dismissSearchOverlay(keepingFilter: false)
                } else if editingRowID != nil {
                    cancelInlineEdit()
                } else {
                    focusedField = nil
                }
            }
            .background {
                keyboardShortcutActions
            }
            .overlay {
                if model.visibleRows.isEmpty {
                    PlaceholderCard(
                        title: model.emptyStateTitle,
                        systemImage: model.emptyStateIcon,
                        message: model.emptyStateMessage
                    )
                }
            }

            HStack {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func activeTaskRow(_ row: PlainShellModel.Row) -> some View {
        HStack {
            Button {
                model.toggleCompletion(lineIdentity: row.id, undoManager: undoManager)
            } label: {
                Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(row.isCompleted ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!model.isEditable)
            .accessibilityLabel(row.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: 6) {
                if editingRowID == row.id {
                    TextField("Edit line", text: $editingRawText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .inlineEdit)
                        .onSubmit {
                            commitInlineEdit(for: row.id)
                        }

                    HStack(spacing: 10) {
                        Button("Save") {
                            commitInlineEdit(for: row.id)
                        }
                        Button("Cancel") {
                            cancelInlineEdit()
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                    .font(.caption)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let priority = row.priority {
                            Text("(\(priority))")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(priorityColor(priority))
                        }

                        SyntaxHighlightedText(
                            text: row.title,
                            query: model.activeSearchQuery,
                            strikethrough: row.isCompleted
                        )

                        Spacer()

                        if let dueLabel = row.dueLabel {
                            Text(dueLabel)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(row.isOverdue ? .red : .secondary)
                        }

                        Menu {
                            Button("Edit") {
                                startInlineEdit(for: row)
                            }
                            Divider()
                            Button("Priority A") {
                                model.setPriority("A", lineIdentity: row.id, undoManager: undoManager)
                            }
                            Button("Priority B") {
                                model.setPriority("B", lineIdentity: row.id, undoManager: undoManager)
                            }
                            Button("Priority C") {
                                model.setPriority("C", lineIdentity: row.id, undoManager: undoManager)
                            }
                            Button("Clear Priority") {
                                model.setPriority(nil, lineIdentity: row.id, undoManager: undoManager)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                model.deleteRow(lineIdentity: row.id, undoManager: undoManager)
                            }
                            Divider()
                            Button("Move Up") {
                                model.moveRow(lineIdentity: row.id, by: -1, undoManager: undoManager)
                            }
                            .disabled(!model.canMove(lineIdentity: row.id, by: -1))
                            Button("Move Down") {
                                model.moveRow(lineIdentity: row.id, by: 1, undoManager: undoManager)
                            }
                            .disabled(!model.canMove(lineIdentity: row.id, by: 1))
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                        .opacity(hoveredRowID == row.id ? 1.0 : 0.0)
                        .disabled(!model.isEditable)
                    }

                    HighlightedText(
                        text: row.rawText,
                        query: model.activeSearchQuery,
                        font: .caption.monospaced(),
                        foregroundStyle: .secondary
                    )
                    .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered in
            hoveredRowID = isHovered ? row.id : nil
        }
        .opacity(row.isCompleted ? 0.5 : 1.0)
        .overlay(alignment: .leading) {
            if model.selectedRowIDs.contains(row.id) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .padding(.vertical, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(taskRowAccessibilityLabel(row))
        .tag(row.id)
    }

    private var archiveDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Done")
                        .font(.largeTitle.weight(.semibold))
                    Text(model.archiveDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Back to tasks") {
                    model.selection = .inbox
                }
                .accessibilityIdentifier("plain.done.back")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if model.hasActiveSearch && !isSearchPresented {
                searchFilterPill
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            List(model.visibleRows) { row in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let priority = row.priority {
                                Text("(\(priority))")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(priorityColor(priority))
                            }

                            SyntaxHighlightedText(
                                text: row.title,
                                query: model.activeSearchQuery,
                                strikethrough: true
                            )

                            Spacer()

                            if let dueLabel = row.dueLabel {
                                Text(dueLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HighlightedText(
                            text: row.rawText,
                            query: model.activeSearchQuery,
                            font: .caption.monospaced(),
                            foregroundStyle: .secondary,
                            strikethrough: true
                        )
                        .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
                .opacity(0.7)
            }
            .listStyle(.inset)
            .accessibilityIdentifier("plain.done.list")
            .onExitCommand {
                if isSearchPresented || focusedField == .search {
                    dismissSearchOverlay(keepingFilter: false)
                } else {
                    model.selection = .inbox
                }
            }
            .overlay {
                if model.visibleRows.isEmpty {
                    PlaceholderCard(
                        title: model.hasActiveSearch ? "No matching archived tasks" : "Nothing archived yet",
                        systemImage: "archivebox",
                        message: model.hasActiveSearch ? "Try a different search or clear the active filter." : "Archive completed tasks to move them here."
                    )
                }
            }

            HStack {
                Text(model.archiveStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var scratchPadDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scratch Pad")
                        .font(.largeTitle.weight(.semibold))
                    Text("Edit the full todo.txt file directly. Saving reparses and writes through the coordinated store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    cancelScratchPad()
                }

                Button("Save") {
                    model.commitScratchPad(undoManager: undoManager)
                }
                .disabled(!model.isEditable)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if model.hasExternalTodoConflict {
                conflictBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            if let transientError = model.transientError {
                Text(transientError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            TextEditor(text: $scratchPadText)
                .font(.body.monospaced())
                .padding(16)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(20)

            HStack {
                Text(model.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var conflictBanner: some View {
        HStack(spacing: 12) {
            Text(model.externalTodoConflictMessage)
                .font(.subheadline)

            Spacer()

            Button("Reload") {
                model.reloadAfterConflict()
            }

            Button("Keep Mine") {
                model.keepMineAfterConflict()
            }

            Button("View Diff") {
                model.presentConflictDiff()
            }
            .accessibilityIdentifier("plain.conflict.viewDiff")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("plain.conflict.banner")
    }

    private func taskRowAccessibilityLabel(_ row: PlainShellModel.Row) -> String {
        var parts: [String] = []
        if row.isCompleted { parts.append("Completed") }
        if let p = row.priority { parts.append("Priority \(p)") }
        parts.append(row.title)
        if let due = row.dueLabel { parts.append(due) }
        return parts.joined(separator: ", ")
    }

    private func startInlineEdit(for row: PlainShellModel.Row) {
        guard model.isEditable else {
            return
        }

        model.selectedRowID = row.id
        editingRowID = row.id
        editingRawText = row.rawText
        focusedField = .inlineEdit
    }

    private func commitInlineEdit(for identity: LineIdentity) {
        let trimmed = editingRawText.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            model.deleteRow(lineIdentity: identity, undoManager: undoManager)
            cancelInlineEdit()
            return
        }

        model.replaceLine(rawText: editingRawText, lineIdentity: identity, undoManager: undoManager)
        cancelInlineEdit()
    }

    private func cancelInlineEdit() {
        editingRowID = nil
        editingRawText = ""
        focusedField = nil
    }

    private func resetDraftUI() {
        newTaskText = ""
        editingRowID = nil
        editingRawText = ""
        scratchPadText = ""
        focusedField = nil
    }

    private func toggleScratchPad() {
        if model.isScratchPadPresented {
            model.commitScratchPad(undoManager: undoManager)
            if !model.isScratchPadPresented {
                scratchPadText = ""
            }
            return

        }

        guard let rawText = model.beginScratchPadEditing() else {
            return
        }

        editingRowID = nil
        editingRawText = ""
        focusedField = nil
        scratchPadText = rawText
    }

    private func cancelScratchPad() {
        model.cancelScratchPadEditing()
        scratchPadText = ""
    }

    private var keyboardShortcutActions: some View {
        VStack {
            Button("Show Search") {
                presentSearchOverlay()
            }
            .keyboardShortcut("f")

            Button("Toggle Selected Completion") {
                guard focusedField == nil else { return }
                let ids = model.selectedRowIDs
                guard !ids.isEmpty else { return }
                for id in ids {
                    model.toggleCompletion(lineIdentity: id, undoManager: undoManager)
                }
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Edit Selected Task") {
                guard focusedField == nil,
                      let selectedRow = model.selectedRow
                else {
                    return
                }

                startInlineEdit(for: selectedRow)
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("Move Selected Task Up") {
                guard focusedField == nil,
                      let selectedRowID = model.selectedRowID,
                      model.canMove(lineIdentity: selectedRowID, by: -1)
                else {
                    return
                }

                model.moveRow(lineIdentity: selectedRowID, by: -1, undoManager: undoManager)
            }
            .keyboardShortcut(.upArrow, modifiers: [.option])

            Button("Move Selected Task Down") {
                guard focusedField == nil,
                      let selectedRowID = model.selectedRowID,
                      model.canMove(lineIdentity: selectedRowID, by: 1)
                else {
                    return
                }

                model.moveRow(lineIdentity: selectedRowID, by: 1, undoManager: undoManager)
            }
            .keyboardShortcut(.downArrow, modifiers: [.option])

            Button("Cycle Sort Mode") {
                model.cycleSortMode()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])

            Button("Set Priority A") {
                guard focusedField == nil else { return }
                for id in model.selectedRowIDs {
                    model.setPriority("A", lineIdentity: id, undoManager: undoManager)
                }
            }
            .keyboardShortcut("1")

            Button("Set Priority B") {
                guard focusedField == nil else { return }
                for id in model.selectedRowIDs {
                    model.setPriority("B", lineIdentity: id, undoManager: undoManager)
                }
            }
            .keyboardShortcut("2")

            Button("Set Priority C") {
                guard focusedField == nil else { return }
                for id in model.selectedRowIDs {
                    model.setPriority("C", lineIdentity: id, undoManager: undoManager)
                }
            }
            .keyboardShortcut("3")

            Button("Clear Priority") {
                guard focusedField == nil else { return }
                for id in model.selectedRowIDs {
                    model.setPriority(nil, lineIdentity: id, undoManager: undoManager)
                }
            }
            .keyboardShortcut("0")

            Button("Select All") {
                guard focusedField == nil else { return }
                model.selectedRowIDs = Set(model.visibleRows.map(\.id))
            }
            .keyboardShortcut("a")
        }
        .frame(width: 0, height: 0)
        .clipped()
        .opacity(0.001)
    }

    private var searchOverlay: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search tasks", text: $searchText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .search)
                .onSubmit {
                    dismissSearchOverlay(keepingFilter: true)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 24)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .search
            }
        }
    }

    private var searchFilterPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
            Text("Showing results for \"\(model.activeSearchQuery)\"")
                .font(.caption.weight(.medium))
            Button {
                clearSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }

    private func presentSearchOverlay() {
        isSearchPresented = true
        if model.hasActiveSearch {
            searchText = model.activeSearchQuery
        }

        DispatchQueue.main.async {
            focusedField = .search
        }
    }

    private func dismissSearchOverlay(keepingFilter: Bool) {
        if !keepingFilter {
            clearSearch()
        }

        isSearchPresented = false
        focusedField = nil
    }

    private func clearSearch() {
        searchText = ""
        model.clearSearch()
    }
}

private struct ConflictDiffSheet: View {
    let diff: PlainShellModel.ConflictDiff
    let reloadAction: () -> Void
    let keepMineAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Resolve Conflict")
                    .font(.title2.weight(.semibold))
                Text("Compare the disk version with your current \(diff.draftTitle.lowercased()) before deciding which one to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                diffColumn(title: "Disk Version", text: diff.diskText)
                diffColumn(title: diff.draftTitle, text: diff.draftText)
            }

            HStack {
                Button("Close") {
                    closeAction()
                }

                Spacer()

                Button("Reload from Disk") {
                    reloadAction()
                }

                Button("Keep My Version") {
                    keepMineAction()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 880, minHeight: 520)
        .accessibilityIdentifier("plain.conflict.diffSheet")
    }

    private func diffColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            TextEditor(text: .constant(text))
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .disabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HighlightedText: View {
    let text: String
    let query: String
    let font: Font
    var foregroundStyle: Color = .primary
    var strikethrough = false

    var body: some View {
        if let matchRange = matchRange {
            let prefix = String(text[..<matchRange.lowerBound])
            let match = String(text[matchRange])
            let suffix = String(text[matchRange.upperBound...])

            HStack(spacing: 0) {
                segment(prefix)
                segment(match, highlighted: true)
                segment(suffix)
            }
        } else {
            segment(text)
        }
    }

    private var matchRange: Range<String.Index>? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return nil
        }

        return text.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive])
    }

    @ViewBuilder
    private func segment(_ value: String, highlighted: Bool = false) -> some View {
        Text(value)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .strikethrough(strikethrough)
            .padding(.horizontal, highlighted ? 2 : 0)
            .background(highlighted ? Color.yellow.opacity(0.28) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "A": return .red
    case "B": return .orange
    case "C": return .blue
    default: return .secondary
    }
}

private struct SyntaxHighlightedText: View {
    let text: String
    let query: String
    var strikethrough = false

    var body: some View {
        let attributed = buildAttributedString()
        if let matchRange = findMatchRange(in: text) {
            let plainPrefix = String(text[..<matchRange.lowerBound])
            let plainMatch = String(text[matchRange])
            let plainSuffix = String(text[matchRange.upperBound...])

            HStack(spacing: 0) {
                styledText(plainPrefix)
                styledText(plainMatch, highlighted: true)
                styledText(plainSuffix)
            }
        } else {
            styledText(text)
        }
    }

    @ViewBuilder
    private func styledText(_ segment: String, highlighted: Bool = false) -> some View {
        Text(coloredAttributedString(segment))
            .strikethrough(strikethrough)
            .padding(.horizontal, highlighted ? 2 : 0)
            .background(highlighted ? Color.yellow.opacity(0.28) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func coloredAttributedString(_ segment: String) -> AttributedString {
        var result = AttributedString()
        let words = segment.split(separator: " ", omittingEmptySubsequences: false)

        for (i, word) in words.enumerated() {
            if i > 0 {
                var space = AttributedString(" ")
                space.font = .body
                space.foregroundColor = .primary
                result.append(space)
            }

            let w = String(word)
            if w.hasPrefix("+") && w.count > 1 {
                var attr = AttributedString(w)
                attr.font = .body.weight(.medium)
                attr.foregroundColor = .teal
                result.append(attr)
            } else if w.hasPrefix("@") && w.count > 1 {
                var attr = AttributedString(w)
                attr.font = .body.weight(.medium)
                attr.foregroundColor = .purple
                result.append(attr)
            } else if w.contains(":") && !w.hasPrefix(":") && !w.hasSuffix(":") && w.count > 2 {
                var attr = AttributedString(w)
                attr.font = .body
                attr.foregroundColor = .secondary
                result.append(attr)
            } else {
                var attr = AttributedString(w)
                attr.font = .body
                attr.foregroundColor = .primary
                result.append(attr)
            }
        }

        return result
    }

    private func buildAttributedString() -> AttributedString {
        coloredAttributedString(text)
    }

    private func findMatchRange(in text: String) -> Range<String.Index>? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive])
    }
}

private struct GroupHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
        .textCase(nil)
    }
}

private struct PlaceholderCard: View {
    let title: String
    let systemImage: String
    let message: String
    var primaryActionTitle: String?
    var primaryAction: (() -> Void)?
    var primaryActionAccessibilityIdentifier: String?
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?
    var secondaryActionAccessibilityIdentifier: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let primaryActionTitle, let primaryAction {
                HStack(spacing: 12) {
                    Button(primaryActionTitle, action: primaryAction)
                        .accessibilityIdentifier(primaryActionAccessibilityIdentifier ?? "")

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
                            .accessibilityIdentifier(secondaryActionAccessibilityIdentifier ?? "")
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct SidebarRow: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count) tasks")
    }
}

enum SidebarSelection: Hashable {
    case inbox
    case today
    case overdue
    case done
    case project(String)
    case context(String)
}

@MainActor
final class PlainShellModel: ObservableObject {
    enum QuickAddError: LocalizedError, Equatable {
        case emptyTask
        case noWritableFile
        case conflict

        var errorDescription: String? {
            switch self {
            case .emptyTask:
                return "Enter a task before submitting quick-add."
            case .noWritableFile:
                return "Open a writable todo.txt file before using quick-add."
            case .conflict:
                return "Resolve the current todo.txt conflict in the main window before using quick-add."
            }
        }
    }

    enum DraftState: Equatable {
        case none
        case newTask(String)
        case inlineEdit(LineIdentity, String)
        case scratchPad(String)

        var conflictDiffTitle: String {
            switch self {
            case .none:
                return "Draft"
            case .newTask:
                return "New Task Draft"
            case .inlineEdit:
                return "Inline Edit Draft"
            case .scratchPad:
                return "Scratch Pad Draft"
            }
        }
    }

    enum ExternalChangeState: Equatable {
        case idle
        case todoConflict
    }

    struct TagCount {
        let name: String
        let count: Int
    }

    struct Row: Identifiable {
        let id: LineIdentity
        let lineIndex: Int
        let title: String
        let rawText: String
        let priority: String?
        let creationDate: TodoDate?
        let isCompleted: Bool
        let dueLabel: String?
        let isOverdue: Bool
    }

    struct RowGroup: Identifiable {
        let id: String
        let title: String?
        let rows: [Row]
    }

    struct ConflictDiff: Identifiable, Equatable {
        let id = "todo-conflict-diff"
        let draftTitle: String
        let diskText: String
        let draftText: String
    }

    @Published var selection: SidebarSelection = .inbox {
        didSet {
            if currentPersistSelection {
                sessionRestore.setSelection(selection)
            }
            if selection != .done {
                sortMode = sortPreferences.sortMode(for: selection)
            }
            refreshVisibleRows()
        }
    }
    @Published var selectedRowIDs: Set<LineIdentity> = []

    var selectedRowID: LineIdentity? {
        get { selectedRowIDs.first }
        set {
            if let newValue {
                selectedRowIDs = [newValue]
            } else {
                selectedRowIDs = []
            }
        }
    }

    @Published private(set) var snapshot: TodoFileSnapshot?
    @Published private(set) var archiveSnapshot: TodoFileSnapshot?
    @Published private(set) var visibleRows: [Row] = []
    @Published private(set) var visibleGroups: [RowGroup] = []
    @Published private(set) var sourceDescription = "Loading sample snapshot"
    @Published private(set) var loadError: String?
    @Published private(set) var transientError: String?
    @Published private(set) var inboxCount = 0
    @Published private(set) var todayCount = 0
    @Published private(set) var overdueCount = 0
    @Published private(set) var doneCount = 0
    @Published private(set) var doneThisWeekCount = 0
    @Published private(set) var archivableCompletedTaskCount = 0
    @Published private(set) var externalChangeState: ExternalChangeState = .idle
    @Published private(set) var draftResetToken = 0
    @Published private(set) var sortMode: TaskSortMode
    @Published private(set) var activeSearchQuery = ""
    @Published private(set) var projectCounts: [TagCount] = []
    @Published private(set) var contextCounts: [TagCount] = []
    @Published private(set) var isScratchPadPresented = false
    @Published private(set) var presentedConflictDiff: ConflictDiff?

    private var hasLoaded = false
    private let preferences: PreferencesStore
    private let sortPreferences: SortPreferenceStore
    private let sessionRestore: SessionRestoreStore
    private let launchArguments: [String]
    private let isUITesting: Bool
    private var cancellables: Set<AnyCancellable> = []
    private var store: CoordinatedTodoStore?
    private var isPersistedSourceEditable = false
    private var currentSourceURL: URL?
    private var currentPersistSelection = false
    private var draftState: DraftState = .none
    private var shouldRestoreSessionSelectionOnNextLoad = false
    private var showCompletedTasks = true
    private let widgetSnapshotDefaults: UserDefaults?

    var isEditable: Bool {
        isPersistedSourceEditable
    }

    var isWaitingForICloud: Bool {
        loadError?.contains("iCloud") == true && snapshot == nil
    }

    var hasExternalTodoConflict: Bool {
        externalChangeState == .todoConflict
    }

    var externalTodoConflictMessage: String {
        "todo.txt changed externally."
    }

    var statusText: String {
        "\(inboxCount) tasks · \(doneThisWeekCount) done this week · \(overdueCount) overdue"
    }

    var archiveStatusText: String {
        "\(doneCount) archived tasks"
    }

    var emptyStateTitle: String {
        if hasActiveSearch { return "No matching tasks" }
        switch selection {
        case .inbox: return "No tasks"
        case .today: return "Nothing due today"
        case .overdue: return "Nothing overdue"
        case .done: return "Nothing archived yet"
        case .project(let p): return "No +\(p) tasks"
        case .context(let c): return "No @\(c) tasks"
        }
    }

    var emptyStateMessage: String {
        if hasActiveSearch { return "Try a different search or clear the active filter." }
        switch selection {
        case .inbox: return "Cmd+N to add a task."
        case .today: return "No deadlines pressing — enjoy the breathing room."
        case .overdue: return "All caught up. Nice."
        case .done: return "Archive completed tasks to move them here."
        case .project(let p): return "No tasks tagged +\(p) right now."
        case .context(let c): return "No @\(c) — nice."
        }
    }

    var emptyStateIcon: String {
        if hasActiveSearch { return "magnifyingglass" }
        switch selection {
        case .inbox: return "text.badge.plus"
        case .today: return "sun.max"
        case .overdue: return "checkmark.seal"
        case .done: return "archivebox"
        case .project: return "folder"
        case .context: return "at"
        }
    }

    var hasActiveSearch: Bool {
        !activeSearchQuery.isEmpty
    }

    var canDragReorder: Bool {
        selection == .inbox && sortMode == .fileOrder && !hasActiveSearch
    }

    var canToggleScratchPad: Bool {
        isScratchPadPresented || (snapshot != nil && selection != .done && isEditable)
    }

    var archiveDescription: String {
        guard let currentSourceURL else {
            return "done.txt"
        }

        return "\(currentSourceURL.deletingLastPathComponent().appendingPathComponent("done.txt").lastPathComponent) · \(doneCount) archived"
    }

    var selectedRow: Row? {
        guard let selectedRowID else {
            return nil
        }

        return visibleRows.first { $0.id == selectedRowID }
    }

    var quickAddDestinationDescription: String {
        guard let currentSourceURL else {
            return "No writable todo.txt selected"
        }

        return currentSourceURL.lastPathComponent
    }

    init(
        preferences: PreferencesStore = PreferencesStore(),
        sortPreferences: SortPreferenceStore = SortPreferenceStore(),
        sessionRestore: SessionRestoreStore = SessionRestoreStore(),
        launchArguments: [String] = Array(CommandLine.arguments.dropFirst()),
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--ui-testing"),
        widgetSnapshotDefaults: UserDefaults? = UserDefaults(suiteName: PlainWidgetConfig.appGroupID)
    ) {
        self.preferences = preferences
        self.sortPreferences = sortPreferences
        self.sessionRestore = sessionRestore
        self.launchArguments = launchArguments
        self.isUITesting = isUITesting
        self.widgetSnapshotDefaults = widgetSnapshotDefaults
        self.showCompletedTasks = preferences.showCompletedTasks
        self.sortMode = sortPreferences.sortMode(for: .inbox)

        preferences.$showCompletedTasks
            .dropFirst()
            .sink { [weak self] showCompletedTasks in
            self?.showCompletedTasks = showCompletedTasks
            self?.refreshPresentationState()
            }
            .store(in: &cancellables)
    }

    func loadInitialSnapshotIfNeeded() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true

        let launch = resolveInitialLaunch()
        shouldRestoreSessionSelectionOnNextLoad = launch.restoreSelection

        if let initialURL = launch.url {
            open(url: initialURL, persistSelection: launch.persistSelection)
        } else {
            PlainWidgetSnapshotStore.clear(defaults: widgetSnapshotDefaults)
            reloadWidgetTimeline()
        }

        if let deepLinkURL = launch.deepLinkURL {
            openDeepLink(deepLinkURL)
        }
    }

    func openDeepLink(_ url: URL) {
        loadInitialSnapshotIfNeeded()

        guard let route = PlainDeepLinkRoute(url: url) else {
            return
        }

        selection = route.selection
    }

    func open(url: URL, persistSelection: Bool = true) {
        do {
            // Check if file is in iCloud and not yet downloaded
            if FileManager.default.isUbiquitousItem(at: url) {
                var resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let status = resourceValues.ubiquitousItemDownloadingStatus
                if status != .current {
                    // Trigger download and show waiting state
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    loadError = "Waiting for iCloud to download \(url.lastPathComponent)…"
                    currentSourceURL = url
                    currentPersistSelection = persistSelection

                    // Retry after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.open(url: url, persistSelection: persistSelection)
                    }
                    return
                }
            }

            store?.stopMonitoring()

            let store = CoordinatedTodoStore(url: url)
            store.onExternalChange = { [weak self] change in
                DispatchQueue.main.async {
                    switch change {
                    case .todo:
                        self?.handleTodoFileChangedExternally()
                    case .archive:
                        self?.handleDoneFileChangedExternally()
                    }
                }
            }
            store.startMonitoring()

            let snapshot = try store.load()
            let archiveSnapshot = try store.loadArchiveSnapshot()
            self.store = store
            self.currentSourceURL = url
            self.currentPersistSelection = persistSelection
            apply(
                todoSnapshot: snapshot,
                archiveSnapshot: archiveSnapshot,
                sourceURL: url,
                persistSelection: persistSelection
            )
        } catch {
            self.store = nil
            present(error: error)
        }
    }

    func loadBundledSample() {
        guard let sampleURL = bundledSampleURL() else {
            present(error: CocoaError(.fileNoSuchFile))
            return
        }

        open(url: sampleURL, persistSelection: false)
    }

    func present(error: Error) {
        snapshot = nil
        archiveSnapshot = nil
        visibleRows = []
        visibleGroups = []
        projectCounts = []
        contextCounts = []
        inboxCount = 0
        todayCount = 0
        overdueCount = 0
        doneCount = 0
        doneThisWeekCount = 0
        archivableCompletedTaskCount = 0
        externalChangeState = .idle
        sourceDescription = "Bootstrap shell"
        loadError = error.localizedDescription
        transientError = nil
        selectedRowID = nil
        isScratchPadPresented = false
        presentedConflictDiff = nil
        PlainWidgetSnapshotStore.clear(defaults: widgetSnapshotDefaults)
        reloadWidgetTimeline()
    }

    func updateDraftState(newTaskText: String, editingRowID: LineIdentity?, editingRawText: String) {
        guard !isScratchPadPresented else {
            return
        }

        if let editingRowID {
            draftState = .inlineEdit(editingRowID, editingRawText)
            return
        }

        let trimmedText = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            draftState = .none
        } else {
            draftState = .newTask(newTaskText)
        }
    }

    func beginScratchPadEditing() -> String? {
        guard let snapshot else {
            return nil
        }

        let rawText = TodoSerializer.serialize(snapshot)
        isScratchPadPresented = true
        draftState = .scratchPad(rawText)
        return rawText
    }

    func updateScratchPadDraft(_ rawText: String) {
        guard isScratchPadPresented else {
            return
        }

        draftState = .scratchPad(rawText)
    }

    func cancelScratchPadEditing() {
        isScratchPadPresented = false
        draftState = .none
        externalChangeState = .idle
    }

    func commitScratchPad(undoManager: UndoManager?) {
        guard let store,
              case let .scratchPad(rawText) = draftState
        else {
            return
        }

        do {
            let transaction = try store.write(snapshot: TodoParser.parse(rawText))
            apply(transaction: transaction)
            registerUndo(actionName: "Edit File", transaction: transaction, undoManager: undoManager)
            isScratchPadPresented = false
            draftState = .none
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func handleTodoFileChangedExternally() {
        if hasActiveDraft {
            externalChangeState = .todoConflict
            return
        }

        do {
            try reloadAllSnapshotsFromDisk()
        } catch {
            present(error: error)
        }
    }

    func handleDoneFileChangedExternally() {
        do {
            try reloadArchiveSnapshotFromDisk()
        } catch {
            present(error: error)
        }
    }

    func reloadAfterConflict() {
        do {
            presentedConflictDiff = nil
            try reloadAllSnapshotsFromDisk()
            clearDraftStateAndRequestReset()
        } catch {
            present(error: error)
        }
    }

    func keepMineAfterConflict() {
        guard let store, let currentSourceURL else {
            return
        }

        do {
            presentedConflictDiff = nil
            let todoSnapshot = try synthesizedTodoSnapshotForCurrentDraft()
            let transaction = try store.write(todoSnapshot: todoSnapshot, doneSnapshot: archiveSnapshot ?? .empty)
            apply(transaction: transaction)
            clearDraftStateAndRequestReset()
            transientError = nil
            sourceDescription = sourceLabel(for: currentSourceURL, snapshot: transaction.updatedTodoSnapshot)
        } catch {
            transientError = error.localizedDescription
        }
    }

    func presentConflictDiff() {
        guard hasExternalTodoConflict else {
            return
        }

        do {
            presentedConflictDiff = try buildConflictDiff()
        } catch {
            transientError = error.localizedDescription
        }
    }

    func dismissConflictDiff() {
        presentedConflictDiff = nil
    }

    func reloadFromConflictDiff() {
        reloadAfterConflict()
    }

    func keepMineFromConflictDiff() {
        keepMineAfterConflict()
    }

    func archiveCompletedTasks(undoManager: UndoManager?) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.archiveCompletedTasks()
            apply(transaction: transaction)
            selection = .inbox
            registerUndo(actionName: "Archive Completed", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func addTask(rawText: String, undoManager: UndoManager?) {
        guard let store else {
            return
        }

        do {
            let parsedText = preparedNewTaskText(from: rawText)
            let transaction = try store.appendTask(rawText: parsedText)
            apply(transaction: transaction)
            selectedRowID = transaction.updatedSnapshot.lines.last?.identity
            registerUndo(actionName: "Add Task", transaction: transaction, undoManager: undoManager)
            draftState = .none
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    @discardableResult
    func addTaskFromQuickAdd(rawText: String) throws -> String {
        loadInitialSnapshotIfNeeded()

        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw QuickAddError.emptyTask
        }

        guard !hasExternalTodoConflict else {
            throw QuickAddError.conflict
        }

        guard isEditable, let store else {
            throw QuickAddError.noWritableFile
        }

        let transformedText = preparedNewTaskText(from: rawText)
        let transaction = try store.appendTask(rawText: transformedText)
        apply(transaction: transaction)
        selectedRowID = transaction.updatedSnapshot.lines.last?.identity
        draftState = .none
        transientError = nil
        return transformedText
    }

    func toggleCompletion(lineIdentity: LineIdentity, undoManager: UndoManager?) {
        guard let store else {
            return
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day else {
            transientError = "Could not derive today’s date."
            return
        }

        let completionDate = TodoDate(year: year, month: month, day: day)

        if preferences.archiveBehavior == .automatic,
           let snapshot,
           let lineIndex = snapshot.lineIndex(for: lineIdentity),
           snapshot.lines.indices.contains(lineIndex),
           snapshot.lines[lineIndex].task?.isCompleted == false
        {
            do {
                let transaction = try store.completeAndArchive(lineIdentity: lineIdentity, completionDate: completionDate)
                apply(transaction: transaction)
                registerUndo(actionName: "Complete and Archive", transaction: transaction, undoManager: undoManager)
                transientError = nil
            } catch {
                transientError = error.localizedDescription
            }
            return
        }

        do {
            let transaction = try store.toggleCompletion(lineIdentity: lineIdentity, completionDate: completionDate)
            apply(transaction: transaction)
            selectedRowID = transaction.updatedSnapshot.lineIndex(for: lineIdentity).flatMap { transaction.updatedSnapshot.lines[$0].identity } ?? selectedRowID
            registerUndo(actionName: "Toggle Complete", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func setPriority(_ priority: Character?, lineIdentity: LineIdentity, undoManager: UndoManager?) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.setPriority(priority, lineIdentity: lineIdentity)
            apply(transaction: transaction)
            selectedRowID = transaction.updatedSnapshot.lines.first(where: { $0.rawText == transaction.updatedSnapshot.lines[transaction.originalSnapshot.lineIndex(for: lineIdentity) ?? 0].rawText })?.identity ?? selectedRowID
            registerUndo(actionName: "Set Priority", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func deleteRow(lineIdentity: LineIdentity, undoManager: UndoManager?) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.deleteTask(lineIdentity: lineIdentity)
            apply(transaction: transaction)
            selectedRowID = visibleRows.first?.id
            registerUndo(actionName: "Delete Task", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func moveRow(lineIdentity: LineIdentity, by offset: Int, undoManager: UndoManager?) {
        guard let store, canMove(lineIdentity: lineIdentity, by: offset) else {
            return
        }

        do {
            let transaction = try store.moveLine(lineIdentity: lineIdentity, by: offset)
            apply(transaction: transaction)
            selectedRowID = transaction.updatedSnapshot.lines.first(where: { $0.identity == lineIdentity })?.identity
                ?? transaction.updatedSnapshot.lineIndex(for: lineIdentity).flatMap { transaction.updatedSnapshot.lines[$0].identity }
                ?? selectedRowID
            registerUndo(actionName: offset < 0 ? "Move Task Up" : "Move Task Down", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func moveVisibleRows(fromOffsets offsets: IndexSet, toOffset destination: Int, undoManager: UndoManager?) {
        guard canDragReorder,
              let store,
              let snapshot,
              !visibleRows.isEmpty
        else {
            return
        }

        var reorderedRows = visibleRows
        reorderedRows.move(fromOffsets: offsets, toOffset: destination)

        let movedIdentity = offsets.first.flatMap { visibleRows[$0].id }
        let visibleIdentities = Set(visibleRows.map(\.id))
        let reorderedVisibleLines = reorderedRows.compactMap { row in
            snapshot.lines.first { $0.identity == row.id }
        }

        guard reorderedVisibleLines.count == visibleRows.count else {
            return
        }

        var nextVisibleIndex = 0
        let reorderedSnapshot = TodoFileSnapshot(
            lines: snapshot.lines.map { line in
                guard visibleIdentities.contains(line.identity) else {
                    return line
                }

                defer { nextVisibleIndex += 1 }
                return reorderedVisibleLines[nextVisibleIndex]
            },
            preferredLineEnding: snapshot.preferredLineEnding,
            containsMixedLineEndings: snapshot.containsMixedLineEndings,
            hasTrailingNewline: snapshot.hasTrailingNewline
        )

        do {
            let transaction = try store.write(snapshot: reorderedSnapshot)
            apply(transaction: transaction)
            if let movedIdentity {
                selectedRowID = transaction.updatedSnapshot.lines.first(where: { $0.identity == movedIdentity })?.identity ?? selectedRowID
            }
            registerUndo(actionName: "Reorder Tasks", transaction: transaction, undoManager: undoManager)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func replaceLine(rawText: String, lineIdentity: LineIdentity, undoManager: UndoManager?) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.replaceLine(rawText: rawText, lineIdentity: lineIdentity)
            apply(transaction: transaction)
            selectedRowID = transaction.updatedSnapshot.lines.first(where: { $0.rawText == rawText })?.identity ?? selectedRowID
            registerUndo(actionName: "Edit Task", transaction: transaction, undoManager: undoManager)
            draftState = .none
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func moveSelection(by offset: Int) {
        guard !visibleRows.isEmpty else {
            selectedRowID = nil
            return
        }

        guard let selectedRowID,
              let currentIndex = visibleRows.firstIndex(where: { $0.id == selectedRowID })
        else {
            selectedRowID = visibleRows.first?.id
            return
        }

        let nextIndex = max(0, min(visibleRows.count - 1, currentIndex + offset))
        self.selectedRowID = visibleRows[nextIndex].id
    }

    func canMove(lineIdentity: LineIdentity, by offset: Int) -> Bool {
        guard selection == .inbox,
              let snapshot,
              let lineIndex = snapshot.lineIndex(for: lineIdentity)
        else {
            return false
        }

        let destinationIndex = lineIndex + offset
        return snapshot.lines.indices.contains(destinationIndex)
    }

    func setSortMode(_ sortMode: TaskSortMode) {
        guard selection != .done else {
            return
        }

        self.sortMode = sortMode
        sortPreferences.setSortMode(sortMode, for: selection)
        refreshVisibleRows()
    }

    func cycleSortMode() {
        setSortMode(sortMode.next)
    }

    func previewTextForNewTask(_ rawText: String) -> String? {
        guard DatePhraseParser.preview(for: rawText) != nil else {
            return nil
        }

        return preparedNewTaskText(from: rawText)
    }

    func setSearchQuery(_ query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        activeSearchQuery = normalizedQuery
        refreshVisibleRows()
    }

    func clearSearch() {
        setSearchQuery("")
    }

    private func resolveInitialLaunch() -> (url: URL?, persistSelection: Bool, restoreSelection: Bool, deepLinkURL: URL?) {
        if isUITesting {
            return (nil, false, false, nil)
        }

        let deepLinkURL = launchDeepLinkArgument()

        if let inlineArgument = launchArguments.first(where: { $0.hasPrefix("--todo-file=") }) {
            let path = String(inlineArgument.dropFirst("--todo-file=".count))
            return (URL(fileURLWithPath: NSString(string: path).expandingTildeInPath), true, false, deepLinkURL)
        }

        if let flagIndex = launchArguments.firstIndex(of: "--todo-file"),
           launchArguments.indices.contains(flagIndex + 1)
        {
            let path = launchArguments[flagIndex + 1]
            return (URL(fileURLWithPath: NSString(string: path).expandingTildeInPath), true, false, deepLinkURL)
        }

        if launchArguments.count == 1,
           let providedPath = launchArguments.first,
           !providedPath.hasPrefix("-")
        {
            if let standaloneURL = URL(string: providedPath),
               PlainDeepLinkRoute(url: standaloneURL) != nil
            {
                return (sessionRestore.restoredSourceURL(), true, sessionRestore.restoredSourceURL() != nil, standaloneURL)
            }

            return (URL(fileURLWithPath: NSString(string: providedPath).expandingTildeInPath), true, false, deepLinkURL)
        }

        if let restoredURL = sessionRestore.restoredSourceURL() {
            return (restoredURL, true, true, deepLinkURL)
        }

        return (nil, false, false, deepLinkURL)
    }

    private func launchDeepLinkArgument() -> URL? {
        if let inlineArgument = launchArguments.first(where: { $0.hasPrefix("--deep-link=") }) {
            let link = String(inlineArgument.dropFirst("--deep-link=".count))
            if let url = URL(string: link), PlainDeepLinkRoute(url: url) != nil {
                return url
            }
        }

        if let flagIndex = launchArguments.firstIndex(of: "--deep-link"),
           launchArguments.indices.contains(flagIndex + 1)
        {
            let link = launchArguments[flagIndex + 1]
            if let url = URL(string: link), PlainDeepLinkRoute(url: url) != nil {
                return url
            }
        }

        return nil
    }

    private func bundledSampleURL() -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "sample", withExtension: "txt", subdirectory: "Resources")
        #else
        return Bundle.main.url(forResource: "sample", withExtension: "txt")
        #endif
    }

    private func applyReloadResult(
        _ result: Result<TodoFileSnapshot, Error>,
        sourceURL: URL,
        persistSelection: Bool
    ) {
        switch result {
        case let .success(snapshot):
            do {
                let archiveSnapshot = try store?.loadArchiveSnapshot() ?? .empty
                apply(
                    todoSnapshot: snapshot,
                    archiveSnapshot: archiveSnapshot,
                    sourceURL: sourceURL,
                    persistSelection: persistSelection
                )
            } catch {
                present(error: error)
            }
        case let .failure(error):
            present(error: error)
        }
    }

    private func apply(
        todoSnapshot: TodoFileSnapshot,
        archiveSnapshot: TodoFileSnapshot,
        sourceURL: URL,
        persistSelection: Bool
    ) {
        self.snapshot = todoSnapshot
        self.archiveSnapshot = archiveSnapshot
        self.loadError = nil
        if externalChangeState != .todoConflict {
            self.transientError = nil
        }
        self.isPersistedSourceEditable = persistSelection && FileManager.default.isWritableFile(atPath: sourceURL.path)

        if persistSelection {
            sessionRestore.setSourceURL(sourceURL)
        }

        let indexedTasks = todoSnapshot.lines.enumerated().compactMap { index, line -> IndexedTask? in
            guard let task = line.task else {
                return nil
            }

            return IndexedTask(index: index, line: line, task: task)
        }

        refreshPresentationState(
            sourceURL: sourceURL,
            todoSnapshot: todoSnapshot,
            archiveSnapshot: archiveSnapshot,
            tasks: indexedTasks
        )
    }

    private func refreshPresentationState() {
        guard let snapshot, let currentSourceURL else {
            return
        }

        let indexedTasks = snapshot.lines.enumerated().compactMap { index, line -> IndexedTask? in
            guard let task = line.task else {
                return nil
            }

            return IndexedTask(index: index, line: line, task: task)
        }

        refreshPresentationState(
            sourceURL: currentSourceURL,
            todoSnapshot: snapshot,
            archiveSnapshot: archiveSnapshot ?? .empty,
            tasks: indexedTasks
        )
    }

    private func refreshPresentationState(
        sourceURL: URL,
        todoSnapshot: TodoFileSnapshot,
        archiveSnapshot: TodoFileSnapshot,
        tasks indexedTasks: [IndexedTask]
    ) {

        let incompleteTasks = indexedTasks.filter { !$0.task.isCompleted }
        let completedTasks = indexedTasks.filter(\.task.isCompleted)
        let visibleActiveTasks = showCompletedTasks ? indexedTasks : incompleteTasks
        let archivedTasks = archiveSnapshot.tasks

        inboxCount = visibleActiveTasks.count
        todayCount = visibleActiveTasks.filter { $0.dueBucket(relativeTo: Date()) == .today }.count
        overdueCount = visibleActiveTasks.filter { $0.dueBucket(relativeTo: Date()) == .overdue }.count
        doneCount = archivedTasks.count
        doneThisWeekCount = Self.countDoneThisWeek(archivedTasks)
        archivableCompletedTaskCount = completedTasks.count
        projectCounts = buildTagCounts(from: visibleActiveTasks, keyPath: \.task.projects)
        contextCounts = buildTagCounts(from: visibleActiveTasks, keyPath: \.task.contexts)
        sourceDescription = sourceLabel(for: sourceURL, snapshot: todoSnapshot)

        if shouldRestoreSessionSelectionOnNextLoad {
            shouldRestoreSessionSelectionOnNextLoad = false
            let restoredSelection = validatedRestoredSelection() ?? .inbox
            if selection != restoredSelection {
                selection = restoredSelection
            } else {
                refreshVisibleRows(tasks: indexedTasks)
            }
        } else {
            refreshVisibleRows(tasks: indexedTasks)
        }
    }

    private func preparedNewTaskText(from rawText: String, referenceDate: Date = Date()) -> String {
        let transformedDueText = DatePhraseParser.preview(for: rawText, referenceDate: referenceDate)?.transformedText ?? rawText
        guard preferences.automaticallyAddCreationDate else {
            return transformedDueText
        }

        return applyingCreationDateIfNeeded(to: transformedDueText, referenceDate: referenceDate)
    }

    private func applyingCreationDateIfNeeded(to rawText: String, referenceDate: Date) -> String {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return rawText
        }

        let parsedLine = TodoParser.parseLine(rawText, lineNumber: 0, originalLineEnding: nil)
        guard let task = parsedLine.task,
              !task.isCompleted,
              task.creationDate == nil
        else {
            return rawText
        }

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        guard let year = components.year,
              let month = components.month,
              let day = components.day
        else {
            return rawText
        }

        let updatedTask = TodoTask(
            isCompleted: task.isCompleted,
            priority: task.priority,
            completionDate: task.completionDate,
            creationDate: TodoDate(year: year, month: month, day: day),
            body: task.body,
            projects: task.projects,
            contexts: task.contexts,
            metadata: task.metadata
        )
        return updatedTask.renderedRawText()
    }

    private func apply(transaction: WriteTransaction) {
        guard let currentSourceURL else {
            return
        }

        apply(
            todoSnapshot: transaction.updatedSnapshot,
            archiveSnapshot: archiveSnapshot ?? .empty,
            sourceURL: currentSourceURL,
            persistSelection: currentPersistSelection
        )
    }

    private func apply(transaction: ArchiveTransaction) {
        guard let currentSourceURL else {
            return
        }

        apply(
            todoSnapshot: transaction.updatedTodoSnapshot,
            archiveSnapshot: transaction.updatedDoneSnapshot,
            sourceURL: currentSourceURL,
            persistSelection: currentPersistSelection
        )
    }

    private var hasActiveDraft: Bool {
        draftState != .none
    }

    private func reloadAllSnapshotsFromDisk() throws {
        guard let store, let currentSourceURL else {
            return
        }

        let reloaded = try store.reloadAll()
        externalChangeState = .idle
        apply(
            todoSnapshot: reloaded.todo,
            archiveSnapshot: reloaded.archive,
            sourceURL: currentSourceURL,
            persistSelection: currentPersistSelection
        )
    }

    private func reloadArchiveSnapshotFromDisk() throws {
        guard let store, let currentSourceURL, let currentSnapshot = snapshot else {
            return
        }

        let reloadedArchiveSnapshot = try store.loadArchiveSnapshot()
        apply(
            todoSnapshot: currentSnapshot,
            archiveSnapshot: reloadedArchiveSnapshot,
            sourceURL: currentSourceURL,
            persistSelection: currentPersistSelection
        )
    }

    private func synthesizedTodoSnapshotForCurrentDraft() throws -> TodoFileSnapshot {
        guard let snapshot else {
            throw CocoaError(.fileReadUnknown)
        }

        switch draftState {
        case .none:
            return snapshot
        case let .newTask(rawText):
            return TaskMutation.append(rawText: rawText, to: snapshot)
        case let .inlineEdit(lineIdentity, rawText):
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            if rawText.trimmingCharacters(in: .newlines).isEmpty {
                return try TaskMutation.deleteLine(at: lineIndex, in: snapshot)
            }

            return try TaskMutation.replaceLine(with: rawText, at: lineIndex, in: snapshot)
        case let .scratchPad(rawText):
            return TodoParser.parse(rawText)
        }
    }

    private func clearDraftStateAndRequestReset() {
        draftState = .none
        isScratchPadPresented = false
        presentedConflictDiff = nil
        externalChangeState = .idle
        draftResetToken += 1
    }

    private func buildConflictDiff() throws -> ConflictDiff {
        guard let store else {
            throw CocoaError(.fileReadUnknown)
        }

        let diskSnapshots = try store.reloadAll()
        let draftSnapshot = try synthesizedTodoSnapshotForCurrentDraft()
        return ConflictDiff(
            draftTitle: draftState.conflictDiffTitle,
            diskText: TodoSerializer.serialize(diskSnapshots.todo),
            draftText: TodoSerializer.serialize(draftSnapshot)
        )
    }

    private func registerUndo(actionName: String, transaction: WriteTransaction, undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreSnapshot(
                transaction.originalSnapshot,
                inverseSnapshot: transaction.updatedSnapshot,
                actionName: actionName,
                undoManager: undoManager
            )
        }
        undoManager?.setActionName(actionName)
    }

    private func registerUndo(actionName: String, transaction: ArchiveTransaction, undoManager: UndoManager?) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreArchiveSnapshots(
                todoSnapshot: transaction.originalTodoSnapshot,
                doneSnapshot: transaction.originalDoneSnapshot,
                inverseTodoSnapshot: transaction.updatedTodoSnapshot,
                inverseDoneSnapshot: transaction.updatedDoneSnapshot,
                actionName: actionName,
                undoManager: undoManager
            )
        }
        undoManager?.setActionName(actionName)
    }

    private func restoreSnapshot(
        _ snapshot: TodoFileSnapshot,
        inverseSnapshot: TodoFileSnapshot,
        actionName: String,
        undoManager: UndoManager?
    ) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.write(snapshot: snapshot)
            apply(transaction: transaction)
            undoManager?.registerUndo(withTarget: self) { target in
                target.restoreSnapshot(
                    inverseSnapshot,
                    inverseSnapshot: snapshot,
                    actionName: actionName,
                    undoManager: undoManager
                )
            }
            undoManager?.setActionName(actionName)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    private func restoreArchiveSnapshots(
        todoSnapshot: TodoFileSnapshot,
        doneSnapshot: TodoFileSnapshot,
        inverseTodoSnapshot: TodoFileSnapshot,
        inverseDoneSnapshot: TodoFileSnapshot,
        actionName: String,
        undoManager: UndoManager?
    ) {
        guard let store else {
            return
        }

        do {
            let transaction = try store.write(todoSnapshot: todoSnapshot, doneSnapshot: doneSnapshot)
            apply(transaction: transaction)
            undoManager?.registerUndo(withTarget: self) { target in
                target.restoreArchiveSnapshots(
                    todoSnapshot: inverseTodoSnapshot,
                    doneSnapshot: inverseDoneSnapshot,
                    inverseTodoSnapshot: todoSnapshot,
                    inverseDoneSnapshot: doneSnapshot,
                    actionName: actionName,
                    undoManager: undoManager
                )
            }
            undoManager?.setActionName(actionName)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    private func refreshVisibleRows(tasks providedTasks: [IndexedTask]? = nil) {
        let todoSnapshot = snapshot ?? .empty
        let archiveSnapshot = archiveSnapshot ?? .empty
        let indexedTasks = providedTasks ?? todoSnapshot.lines.enumerated().compactMap { index, line -> IndexedTask? in
            guard let task = line.task else {
                return nil
            }

            return IndexedTask(index: index, line: line, task: task)
        }

        if selection == .done {
            visibleRows = applySearchFilter(to: buildArchiveRows(from: archiveSnapshot))
        } else {
            visibleRows = applySearchFilter(to: buildVisibleRows(from: todoSnapshot, tasks: indexedTasks))
        }

        visibleGroups = buildVisibleGroups(from: visibleRows)

        if let selectedRowID, visibleRows.contains(where: { $0.id == selectedRowID }) {
            self.selectedRowID = selectedRowID
        } else {
            self.selectedRowID = visibleRows.first?.id
        }

        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        let snapshot = PlainWidgetSnapshotFactory.make(
            sourceDescription: sourceDescription,
            selection: widgetSelection(for: selection),
            inboxCount: inboxCount,
            todayCount: todayCount,
            overdueCount: overdueCount,
            doneCount: doneCount,
            previewTasks: visibleRows.map(\.rawText)
        )

        PlainWidgetSnapshotStore.save(snapshot, defaults: widgetSnapshotDefaults)
        reloadWidgetTimeline()
    }

    private func widgetSelection(for selection: SidebarSelection) -> PlainWidgetSelection {
        switch selection {
        case .inbox:
            return .inbox
        case .today:
            return .today
        case .overdue:
            return .overdue
        case .done:
            return .done
        case let .project(project):
            return .project(project)
        case let .context(context):
            return .context(context)
        }
    }

    private func reloadWidgetTimeline() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: PlainWidgetConfig.widgetKind)
        #endif
    }

    private func buildTagCounts(
        from tasks: [IndexedTask],
        keyPath: KeyPath<IndexedTask, [String]>
    ) -> [TagCount] {
        var counts: [String: Int] = [:]

        for task in tasks {
            for name in Set(task[keyPath: keyPath]) {
                counts[name, default: 0] += 1
            }
        }

        return counts.keys.sorted().map { TagCount(name: $0, count: counts[$0, default: 0]) }
    }

    private func applySearchFilter(to rows: [Row]) -> [Row] {
        guard !activeSearchQuery.isEmpty else {
            return rows
        }

        return rows.filter { $0.rawText.localizedCaseInsensitiveContains(activeSearchQuery) }
    }

    private func validatedRestoredSelection() -> SidebarSelection? {
        guard let restoredSelection = sessionRestore.restoredSelection() else {
            return nil
        }

        switch restoredSelection {
        case .inbox, .today, .overdue, .done:
            return restoredSelection
        case let .project(project):
            return projectCounts.contains(where: { $0.name == project }) ? restoredSelection : .inbox
        case let .context(context):
            return contextCounts.contains(where: { $0.name == context }) ? restoredSelection : .inbox
        }
    }

    private func buildVisibleGroups(from rows: [Row]) -> [RowGroup] {
        guard selection != .done else {
            return [RowGroup(id: "flat", title: nil, rows: rows)]
        }

        switch sortMode {
        case .fileOrder, .alphabetical:
            return [RowGroup(id: "flat", title: nil, rows: rows)]
        case .priority:
            return Dictionary(grouping: rows) { priorityGroupTitle(for: $0) }
                .sorted { lhs, rhs in priorityGroupRank(lhs.key) < priorityGroupRank(rhs.key) }
                .map { title, groupedRows in
                    RowGroup(id: title, title: title, rows: groupedRows)
                }
        case .creationDate:
            return Dictionary(grouping: rows) { creationDateGroupTitle(for: $0.creationDate, relativeTo: Date()) }
                .sorted { lhs, rhs in creationDateGroupRank(lhs.key) < creationDateGroupRank(rhs.key) }
                .map { title, groupedRows in
                    RowGroup(id: title, title: title, rows: groupedRows)
                }
        }
    }

    private func priorityGroupTitle(for row: Row) -> String {
        guard let priority = row.priority else {
            return "No Priority"
        }

        return "Priority \(priority)"
    }

    private func priorityGroupRank(_ title: String) -> Int {
        guard title != "No Priority",
              let scalar = title.last?.asciiValue
        else {
            return Int.max
        }

        return Int(scalar)
    }

    private func creationDateGroupTitle(for creationDate: TodoDate?, relativeTo now: Date) -> String {
        guard let creationDate, let date = date(from: creationDate) else {
            return "No Date"
        }

        let calendar = Calendar(identifier: .gregorian)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return date > now ? "Later" : "This Week"
        }

        return date > now ? "Later" : "Earlier"
    }

    private func creationDateGroupRank(_ title: String) -> Int {
        switch title {
        case "Today":
            return 0
        case "This Week":
            return 1
        case "Earlier":
            return 2
        case "Later":
            return 3
        case "No Date":
            return 4
        default:
            return 5
        }
    }

    private func date(from todoDate: TodoDate) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = todoDate.year
        components.month = todoDate.month
        components.day = todoDate.day
        return components.date
    }

    private func buildVisibleRows(from snapshot: TodoFileSnapshot, tasks: [IndexedTask]) -> [Row] {
        if sortMode != .fileOrder {
            return tasks
                .filter(matchesSelection)
                .filter(isVisibleInActiveViews)
                .sorted(by: sortComparator)
                .map(makeRow)
        }

        return snapshot.lines.enumerated().compactMap { index, line -> Row? in
            let indexedTask = tasks.first { $0.index == index }

            if let indexedTask {
                guard matchesSelection(indexedTask), isVisibleInActiveViews(indexedTask) else {
                    return nil
                }

                return Row(
                    id: line.identity,
                    lineIndex: index,
                    title: indexedTask.task.body.isEmpty ? line.rawText : indexedTask.task.body,
                    rawText: line.rawText,
                    priority: indexedTask.task.priority.map(String.init),
                    creationDate: indexedTask.task.creationDate,
                    isCompleted: indexedTask.task.isCompleted,
                    dueLabel: indexedTask.dueLabel(relativeTo: Date()),
                    isOverdue: indexedTask.dueBucket(relativeTo: Date()) == .overdue
                )
            }

            guard selection == .inbox else {
                return nil
            }

            return Row(
                id: line.identity,
                lineIndex: index,
                title: line.rawText.isEmpty ? "Blank line" : line.rawText,
                rawText: line.rawText,
                priority: nil,
                creationDate: nil,
                isCompleted: false,
                dueLabel: nil,
                isOverdue: false
            )
        }
    }

    private func makeRow(from indexedTask: IndexedTask) -> Row {
        Row(
            id: indexedTask.line.identity,
            lineIndex: indexedTask.index,
            title: indexedTask.task.body.isEmpty ? indexedTask.line.rawText : indexedTask.task.body,
            rawText: indexedTask.line.rawText,
            priority: indexedTask.task.priority.map(String.init),
            creationDate: indexedTask.task.creationDate,
            isCompleted: indexedTask.task.isCompleted,
            dueLabel: indexedTask.dueLabel(relativeTo: Date()),
            isOverdue: indexedTask.dueBucket(relativeTo: Date()) == .overdue
        )
    }

    private func sortComparator(_ lhs: IndexedTask, _ rhs: IndexedTask) -> Bool {
        switch sortMode {
        case .fileOrder:
            return lhs.index < rhs.index
        case .priority:
            let lhsPriority = lhs.task.priority.map { Int($0.asciiValue ?? 91) } ?? Int.max
            let rhsPriority = rhs.task.priority.map { Int($0.asciiValue ?? 91) } ?? Int.max

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            return lhs.index < rhs.index
        case .creationDate:
            switch (lhs.task.creationDate, rhs.task.creationDate) {
            case let (.some(lhsDate), .some(rhsDate)):
                if lhsDate.year != rhsDate.year {
                    return lhsDate.year > rhsDate.year
                }

                if lhsDate.month != rhsDate.month {
                    return lhsDate.month > rhsDate.month
                }

                if lhsDate.day != rhsDate.day {
                    return lhsDate.day > rhsDate.day
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.index < rhs.index
        case .alphabetical:
            let comparison = lhs.task.body.localizedCaseInsensitiveCompare(rhs.task.body)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return lhs.index < rhs.index
        }
    }

    private func buildArchiveRows(from snapshot: TodoFileSnapshot) -> [Row] {
        snapshot.lines.enumerated().reversed().compactMap { index, line in
            guard let task = line.task else {
                return nil
            }

            let indexedTask = IndexedTask(index: index, line: line, task: task)
            return Row(
                id: line.identity,
                lineIndex: index,
                title: task.body.isEmpty ? line.rawText : task.body,
                rawText: line.rawText,
                priority: task.priority.map(String.init),
                creationDate: task.creationDate,
                isCompleted: true,
                dueLabel: indexedTask.dueLabel(relativeTo: Date()),
                isOverdue: false
            )
        }
    }

    private func matchesSelection(_ indexedTask: IndexedTask) -> Bool {
        switch selection {
        case .inbox:
            return true
        case .today:
            return indexedTask.dueBucket(relativeTo: Date()) == .today
        case .overdue:
            return indexedTask.dueBucket(relativeTo: Date()) == .overdue
        case .done:
            return false
        case let .project(project):
            return indexedTask.task.projects.contains(project)
        case let .context(context):
            return indexedTask.task.contexts.contains(context)
        }
    }

    private func isVisibleInActiveViews(_ indexedTask: IndexedTask) -> Bool {
        showCompletedTasks || !indexedTask.task.isCompleted
    }

    private func sourceLabel(for url: URL, snapshot: TodoFileSnapshot) -> String {
        let newlineNote = snapshot.containsMixedLineEndings ? "mixed newlines" : snapshot.preferredLineEnding.rawValue.debugDescription
        return "Read-only bootstrap shell · \(url.lastPathComponent) · \(inboxCount) open · \(doneCount) done · \(newlineNote)"
    }

    static func countDoneThisWeek(_ tasks: [TodoTask]) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }
        return tasks.filter { task in
            guard let cd = task.completionDate else { return false }
            var components = DateComponents()
            components.calendar = calendar
            components.year = cd.year
            components.month = cd.month
            components.day = cd.day
            guard let date = components.date else { return false }
            return date >= weekStart && date <= now
        }.count
    }
}

private extension PlainShellModel {
    struct IndexedTask {
        enum DueBucket {
            case none
            case today
            case overdue
            case upcoming
        }

        let index: Int
        let line: TodoLine
        let task: TodoTask

        func dueBucket(relativeTo now: Date) -> DueBucket {
            guard let dueDate = parsedDueDate else {
                return .none
            }

            let calendar = Calendar(identifier: .gregorian)
            if calendar.isDate(dueDate, inSameDayAs: now) {
                return .today
            }

            return dueDate < calendar.startOfDay(for: now) ? .overdue : .upcoming
        }

        func dueLabel(relativeTo now: Date) -> String? {
            guard let due = dueMetadataValue else {
                return nil
            }

            switch dueBucket(relativeTo: now) {
            case .today:
                return "Today"
            case .overdue:
                return "Overdue"
            case .upcoming, .none:
                return due
            }
        }

        private var dueMetadataValue: String? {
            task.metadata.first { $0.key == "due" }?.value
        }

        private var parsedDueDate: Date? {
            guard let dueMetadataValue,
                  let due = TodoDate(rawValue: dueMetadataValue)
            else {
                return nil
            }

            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.year = due.year
            components.month = due.month
            components.day = due.day
            return components.date
        }
    }
}
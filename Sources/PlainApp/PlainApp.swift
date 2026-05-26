import PlainCore
import SwiftUI
import UniformTypeIdentifiers

private enum FocusField: Hashable {
    case newTask
    case inlineEdit
    case search
}

@main
struct PlainApp: App {
    @StateObject private var preferences = PreferencesStore()

    var body: some Scene {
        WindowGroup {
            PlainShellView(preferences: preferences)
        }

        Settings {
            PreferencesView(preferences: preferences)
        }
    }
}

private struct PlainShellView: View {
    @StateObject private var model: PlainShellModel
    @Environment(\.undoManager) private var undoManager
    @State private var isFileImporterPresented = false
    @State private var isArchiveConfirmationPresented = false
    @State private var isSearchPresented = false
    @State private var newTaskText = ""
    @State private var searchText = ""
    @State private var editingRowID: LineIdentity?
    @State private var editingRawText = ""
    @FocusState private var focusedField: FocusField?

    init(preferences: PreferencesStore = PreferencesStore()) {
        _model = StateObject(wrappedValue: PlainShellModel(preferences: preferences))
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            Group {
                if model.snapshot == nil, model.loadError == nil {
                    onboardingView
                } else if let loadError = model.loadError {
                    PlaceholderCard(
                        title: "Unable to load todo.txt",
                        systemImage: "exclamationmark.triangle",
                        message: loadError,
                        primaryActionTitle: "Open an existing file",
                        primaryAction: { isFileImporterPresented = true },
                        secondaryActionTitle: "Use bundled sample",
                        secondaryAction: { model.loadBundledSample() }
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
                    guard let selectedRowID = model.selectedRowID else {
                        return
                    }

                    model.toggleCompletion(lineIdentity: selectedRowID, undoManager: undoManager)
                }
                .keyboardShortcut("d")

                Button("Archive Completed") {
                    isArchiveConfirmationPresented = true
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])
                .disabled(!model.isEditable || model.archivableCompletedTaskCount == 0)

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
        DatePhraseParser.preview(for: newTaskText)
    }

    private var detailView: some View {
        Group {
            if model.selection == .done {
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

            List(selection: $model.selectedRowID) {
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
            .onDeleteCommand {
                guard let selectedRowID = model.selectedRowID else {
                    return
                }

                model.deleteRow(lineIdentity: selectedRowID, undoManager: undoManager)
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
                        title: model.hasActiveSearch ? "No matching tasks" : "Nothing here yet",
                        systemImage: "line.3.horizontal.decrease.circle",
                        message: model.hasActiveSearch ? "Try a different search or clear the active filter." : "This view is empty for the current filter."
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
                                .foregroundStyle(.orange)
                        }

                        HighlightedText(
                            text: row.title,
                            query: model.activeSearchQuery,
                            font: .body,
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
                                    .foregroundStyle(.orange)
                            }

                            HighlightedText(
                                text: row.title,
                                query: model.activeSearchQuery,
                                font: .body,
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
                        message: model.hasActiveSearch ? "Try a different search or clear the active filter." : "Archive completed tasks to move them into done.txt."
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("plain.conflict.banner")
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
        focusedField = nil
    }

    private var keyboardShortcutActions: some View {
        VStack {
            Button("Show Search") {
                presentSearchOverlay()
            }
            .keyboardShortcut("f")

            Button("Toggle Selected Completion") {
                guard focusedField == nil,
                      let selectedRowID = model.selectedRowID
                else {
                    return
                }

                model.toggleCompletion(lineIdentity: selectedRowID, undoManager: undoManager)
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
    enum DraftState: Equatable {
        case none
        case newTask(String)
        case inlineEdit(LineIdentity, String)
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

    @Published var selection: SidebarSelection = .inbox {
        didSet {
            if selection != .done {
                sortMode = sortPreferences.sortMode(for: selection)
            }
            refreshVisibleRows()
        }
    }
    @Published var selectedRowID: LineIdentity?
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
    @Published private(set) var archivableCompletedTaskCount = 0
    @Published private(set) var externalChangeState: ExternalChangeState = .idle
    @Published private(set) var draftResetToken = 0
    @Published private(set) var sortMode: TaskSortMode
    @Published private(set) var activeSearchQuery = ""
    @Published private(set) var projectCounts: [TagCount] = []
    @Published private(set) var contextCounts: [TagCount] = []

    private var hasLoaded = false
    private let userDefaults = UserDefaults.standard
    private let persistedFilePathKey = "PlainBootstrapSelectedFilePath"
    private let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private let preferences: PreferencesStore
    private let sortPreferences: SortPreferenceStore
    private var store: CoordinatedTodoStore?
    private var isPersistedSourceEditable = false
    private var currentSourceURL: URL?
    private var currentPersistSelection = false
    private var draftState: DraftState = .none

    var isEditable: Bool {
        isPersistedSourceEditable
    }

    var hasExternalTodoConflict: Bool {
        externalChangeState == .todoConflict
    }

    var externalTodoConflictMessage: String {
        "todo.txt changed externally."
    }

    var statusText: String {
        "\(inboxCount) tasks · \(doneCount) done · \(overdueCount) overdue"
    }

    var archiveStatusText: String {
        "\(doneCount) archived tasks"
    }

    var hasActiveSearch: Bool {
        !activeSearchQuery.isEmpty
    }

    var canDragReorder: Bool {
        selection == .inbox && sortMode == .fileOrder && !hasActiveSearch
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

    init(
        preferences: PreferencesStore = PreferencesStore(),
        sortPreferences: SortPreferenceStore = SortPreferenceStore()
    ) {
        self.preferences = preferences
        self.sortPreferences = sortPreferences
        self.sortMode = sortPreferences.sortMode(for: .inbox)
    }

    func loadInitialSnapshotIfNeeded() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true

        if let initialURL = resolveInitialSourceURL() {
            open(url: initialURL, persistSelection: initialURL.path != bundledSampleURL()?.path)
        }
    }

    func open(url: URL, persistSelection: Bool = true) {
        do {
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
        archivableCompletedTaskCount = 0
        externalChangeState = .idle
        sourceDescription = "Bootstrap shell"
        loadError = error.localizedDescription
        transientError = nil
        selectedRowID = nil
    }

    func updateDraftState(newTaskText: String, editingRowID: LineIdentity?, editingRawText: String) {
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
            let parsedText = DatePhraseParser.preview(for: rawText)?.transformedText ?? rawText
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

    func setSearchQuery(_ query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        activeSearchQuery = normalizedQuery
        refreshVisibleRows()
    }

    func clearSearch() {
        setSearchQuery("")
    }

    private func resolveInitialSourceURL() -> URL? {
        if launchArguments.contains("--ui-testing") {
            return nil
        }

        let arguments = Array(CommandLine.arguments.dropFirst())
        if let inlineArgument = arguments.first(where: { $0.hasPrefix("--todo-file=") }) {
            let path = String(inlineArgument.dropFirst("--todo-file=".count))
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        }

        if let flagIndex = arguments.firstIndex(of: "--todo-file"),
           arguments.indices.contains(flagIndex + 1)
        {
            let path = arguments[flagIndex + 1]
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        }

        if arguments.count == 1,
           let providedPath = arguments.first,
           !providedPath.hasPrefix("-")
        {
            return URL(fileURLWithPath: NSString(string: providedPath).expandingTildeInPath)
        }

        if let persistedPath = userDefaults.string(forKey: persistedFilePathKey) {
            return URL(fileURLWithPath: persistedPath)
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
            userDefaults.set(sourceURL.path, forKey: persistedFilePathKey)
        }

        let indexedTasks = todoSnapshot.lines.enumerated().compactMap { index, line -> IndexedTask? in
            guard let task = line.task else {
                return nil
            }

            return IndexedTask(index: index, line: line, task: task)
        }

        let incompleteTasks = indexedTasks.filter { !$0.task.isCompleted }
        let completedTasks = indexedTasks.filter(\.task.isCompleted)
        let archivedTasks = archiveSnapshot.tasks

        inboxCount = incompleteTasks.count
        todayCount = incompleteTasks.filter { $0.dueBucket(relativeTo: Date()) == .today }.count
        overdueCount = incompleteTasks.filter { $0.dueBucket(relativeTo: Date()) == .overdue }.count
        doneCount = archivedTasks.count
        archivableCompletedTaskCount = completedTasks.count
        projectCounts = buildTagCounts(from: incompleteTasks, keyPath: \.task.projects)
        contextCounts = buildTagCounts(from: incompleteTasks, keyPath: \.task.contexts)
        sourceDescription = sourceLabel(for: sourceURL, snapshot: todoSnapshot)
        refreshVisibleRows(tasks: indexedTasks)
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
        }
    }

    private func clearDraftStateAndRequestReset() {
        draftState = .none
        externalChangeState = .idle
        draftResetToken += 1
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
                .sorted(by: sortComparator)
                .map(makeRow)
        }

        return snapshot.lines.enumerated().compactMap { index, line -> Row? in
            let indexedTask = tasks.first { $0.index == index }

            if let indexedTask {
                guard matchesSelection(indexedTask) else {
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
            return !indexedTask.task.isCompleted
        case .today:
            return !indexedTask.task.isCompleted && indexedTask.dueBucket(relativeTo: Date()) == .today
        case .overdue:
            return !indexedTask.task.isCompleted && indexedTask.dueBucket(relativeTo: Date()) == .overdue
        case .done:
            return false
        case let .project(project):
            return !indexedTask.task.isCompleted && indexedTask.task.projects.contains(project)
        case let .context(context):
            return !indexedTask.task.isCompleted && indexedTask.task.contexts.contains(context)
        }
    }

    private func sourceLabel(for url: URL, snapshot: TodoFileSnapshot) -> String {
        let newlineNote = snapshot.containsMixedLineEndings ? "mixed newlines" : snapshot.preferredLineEnding.rawValue.debugDescription
        return "Read-only bootstrap shell · \(url.lastPathComponent) · \(inboxCount) open · \(doneCount) done · \(newlineNote)"
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
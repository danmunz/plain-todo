import AppKit
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

extension Notification.Name {
    static let plainOpenFile = Notification.Name("plainOpenFile")
    static let plainFocusInputBar = Notification.Name("plainFocusInputBar")
    static let plainToggleSidebar = Notification.Name("plainToggleSidebar")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFileImporterPresented = false
    @State private var isArchiveConfirmationPresented = false
    @State private var isSearchPresented = false
    @State private var newTaskText = ""
    @State private var searchText = ""
    @State private var editingRowID: LineIdentity?
    @State private var editingRawText = ""
    @State private var hoveredRowID: LineIdentity?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var scratchPadText = ""
    @State private var highlightedRowID: LineIdentity?
    @State private var completingRowID: LineIdentity?
    @State private var autocompleteSuggestions: [String] = []
    @State private var autocompleteIndex: Int = 0
    @State private var autocompletePrefix: Character?  // '@' or '+'
    @State private var isDueDatePickerPresented = false
    @State private var dueDatePickerValue = Date()
    @State private var columnVisibility: NavigationSplitViewVisibility = {
        if UserDefaults.standard.bool(forKey: "PlainSidebarCollapsed") {
            return .detailOnly
        }
        return .all
    }()
    @FocusState private var focusedField: FocusField?

    init(model: PlainShellModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $model.selection) {
                Section {
                    SidebarRow(title: "Inbox", count: model.inboxCount)
                        .tag(SidebarSelection.inbox)
                    SidebarRow(title: "Today", count: model.todayCount)
                        .tag(SidebarSelection.today)
                    SidebarRow(title: "Overdue", count: model.overdueCount, isOverdue: model.overdueCount > 0)
                        .tag(SidebarSelection.overdue)
                } header: {
                    SidebarSectionHeader("SMART FILTERS")
                }

                if !model.projectCounts.isEmpty {
                    Section {
                        ForEach(model.projectCounts, id: \.name) { project in
                            SidebarRow(title: project.name, count: project.count)
                                .tag(SidebarSelection.project(project.name))
                        }
                    } header: {
                        SidebarSectionHeader("+PROJECTS")
                    }
                }

                if !model.contextCounts.isEmpty {
                    Section {
                        ForEach(model.contextCounts, id: \.name) { context in
                            SidebarRow(title: context.name, count: context.count)
                                .tag(SidebarSelection.context(context.name))
                        }
                    } header: {
                        SidebarSectionHeader("@CONTEXTS")
                    }
                }

                Section {
                    SidebarRow(title: "Done", count: model.doneCount)
                        .tag(SidebarSelection.done)
                } header: {
                    SidebarSectionHeader("ARCHIVE")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PlainTokens.Surface.sidebar)
            .listStyle(.sidebar)
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
        .navigationTitle(model.windowTitle)
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
                Picker("Sort", selection: Binding(get: { model.sortMode }, set: { model.setSortMode($0) })) {
                    ForEach(TaskSortMode.allCases) { sortMode in
                        Text(sortMode.title).tag(sortMode)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.selection == .done)
                .help("Sort Mode (⌘⇧S)")

                Button {
                    toggleScratchPad()
                } label: {
                    Image(systemName: model.isScratchPadPresented ? "doc.text.fill" : "doc.text")
                }
                .keyboardShortcut("e")
                .disabled(!model.canToggleScratchPad)
                .help(model.isScratchPadPresented ? "Save & Return (⌘E)" : "Scratch Pad (⌘E)")

                Button {
                    isArchiveConfirmationPresented = true
                } label: {
                    Image(systemName: "archivebox")
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])
                .disabled(!model.isEditable || model.archivableCompletedTaskCount == 0)
                .help("Archive Completed (⌘⇧A)")
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
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -8)))
                    .animation(reduceMotion ? nil : .easeOut(duration: Anim.fast), value: isSearchPresented)
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
        .onReceive(NotificationCenter.default.publisher(for: .plainOpenFile)) { _ in
            isFileImporterPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .plainFocusInputBar)) { _ in
            focusedField = .newTask
        }
        .onReceive(NotificationCenter.default.publisher(for: .plainToggleSidebar)) { _ in
            withAnimation {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            }
        }
        .onChange(of: columnVisibility) { _, newValue in
            UserDefaults.standard.set(newValue == .detailOnly, forKey: "PlainSidebarCollapsed")
        }
    }

    private var onboardingView: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("plain")
                    .font(PlainType.onboardingHeading)
                    .tracking(Tracking.onboardingHeading)
                    .foregroundStyle(PlainTokens.TextToken.primary)

                Text("A todo.txt client for macOS.\nReads your file. That's it, really.")
                    .font(PlainType.onboardingBody)
                    .foregroundStyle(PlainTokens.TextToken.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: Spacing.lg) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Text("Open an Existing File")
                        .font(PlainType.sidebarLabel)
                        .frame(width: 220)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("plain.onboarding.open")

                Button {
                    model.createNewFile()
                } label: {
                    Text("Create a New File")
                        .font(PlainType.sidebarLabel)
                        .frame(width: 220)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("plain.onboarding.create")

                Button {
                    model.loadBundledSample()
                } label: {
                    Text("Try with a sample file")
                        .font(PlainType.taskMeta)
                        .foregroundStyle(PlainTokens.TextToken.muted)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plain.onboarding.sample")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlainTokens.Surface.canvas)
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
            if let transientError = model.transientError {
                Text(transientError)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.Status.destructive)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
            }

            if model.hasExternalTodoConflict {
                conflictBanner
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus")
                    .foregroundStyle(PlainTokens.TextToken.muted)
                    .font(PlainType.iconMedium)

                TextField("Add a task...", text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(PlainType.inputBar(size: fontSize))
                    .focused($focusedField, equals: .newTask)
                    .disabled(!model.isEditable)
                    .accessibilityIdentifier("plain.add.textField")
                    .accessibilityLabel("Add a task")
                    .accessibilityHint("Type a task and press Return to add it")
                    .onSubmit {
                        if !autocompleteSuggestions.isEmpty {
                            acceptAutocompleteSuggestion(autocompleteSuggestions[autocompleteIndex])
                        } else {
                            submitNewTask()
                        }
                    }
                    .onChange(of: newTaskText) { _, newValue in
                        updateAutocompleteSuggestions(for: newValue)
                    }
                    .onKeyPress(.upArrow) {
                        guard !autocompleteSuggestions.isEmpty else { return .ignored }
                        autocompleteIndex = max(0, autocompleteIndex - 1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        guard !autocompleteSuggestions.isEmpty else { return .ignored }
                        autocompleteIndex = min(autocompleteSuggestions.count - 1, autocompleteIndex + 1)
                        return .handled
                    }
                    .onKeyPress(.tab) {
                        guard !autocompleteSuggestions.isEmpty else { return .ignored }
                        acceptAutocompleteSuggestion(autocompleteSuggestions[autocompleteIndex])
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        if isDueDatePickerPresented {
                            isDueDatePickerPresented = false
                            return .handled
                        }
                        guard !autocompleteSuggestions.isEmpty else { return .ignored }
                        autocompleteSuggestions = []
                        return .handled
                    }

                Spacer()

                if newTaskText.isEmpty && focusedField != .newTask {
                    Text("⌘N")
                        .font(PlainType.inputHint)
                        .foregroundStyle(PlainTokens.TextToken.muted)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(PlainTokens.Surface.input))
                }

                if !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        submitNewTask()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isEditable)
                    .accessibilityIdentifier("plain.add.button")
                    .accessibilityLabel("Add task")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
            .frame(height: Measurement.inputBarHeight)
            .background(PlainTokens.Surface.input)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(focusedField == .newTask ? PlainTokens.Border.inputFocused : PlainTokens.Border.input, lineWidth: focusedField == .newTask ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .overlay(alignment: .topLeading) {
                if !autocompleteSuggestions.isEmpty {
                    let prefix = autocompletePrefix.map(String.init) ?? ""
                    let syntaxColor = autocompletePrefix == "+" ? PlainTokens.Syntax.project : PlainTokens.Syntax.context
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(autocompleteSuggestions.enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                acceptAutocompleteSuggestion(suggestion)
                            } label: {
                                HStack {
                                    Text("\(prefix)\(suggestion)")
                                        .font(PlainType.taskBody)
                                        .foregroundStyle(syntaxColor)
                                    Spacer()
                                    if index < 3 && isRecentTag(suggestion, prefix: autocompletePrefix) {
                                        Text("recent")
                                            .font(PlainType.taskMeta)
                                            .foregroundStyle(PlainTokens.TextToken.muted)
                                    }
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                                .background(index == autocompleteIndex ? PlainTokens.Surface.hover : Color.clear)
                            }
                            .buttonStyle(.plain)
                            if index < autocompleteSuggestions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(PlainTokens.Surface.input)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(PlainTokens.Border.input, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    .frame(maxWidth: 260)
                    .offset(y: Measurement.inputBarHeight + 4)
                    .zIndex(100)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isDueDatePickerPresented {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Due Date")
                                .font(PlainType.sidebarLabel)
                                .foregroundStyle(PlainTokens.TextToken.primary)
                            Spacer()
                            Button {
                                isDueDatePickerPresented = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(PlainTokens.TextToken.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.sm)

                        DatePicker(
                            "Due date",
                            selection: $dueDatePickerValue,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, Spacing.sm)

                        Divider()
                            .padding(.horizontal, Spacing.lg)

                        HStack(spacing: Spacing.md) {
                            Button("Today") {
                                insertDueDate(Date())
                            }
                            .buttonStyle(.plain)
                            .font(PlainType.taskMeta)
                            .foregroundStyle(PlainTokens.Syntax.context)

                            Button("Tomorrow") {
                                insertDueDate(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                            }
                            .buttonStyle(.plain)
                            .font(PlainType.taskMeta)
                            .foregroundStyle(PlainTokens.Syntax.context)

                            Spacer()

                            Button("Set Date") {
                                insertDueDate(dueDatePickerValue)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(PlainTokens.Border.input, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                    .frame(width: 280)
                    .offset(y: Measurement.inputBarHeight + 4)
                    .zIndex(100)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .zIndex(1)

            if let addTaskPreview {
                HStack(spacing: Spacing.sm) {
                    Text("→")
                        .foregroundStyle(PlainTokens.TextToken.muted)
                    SyntaxHighlightedText(
                        text: addTaskPreview.transformedText,
                        query: ""
                    )
                }
                .font(PlainType.taskMeta)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(PlainTokens.Surface.hover)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }

            if model.hasActiveSearch && !isSearchPresented {
                searchFilterPill
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
            }

            if !model.isEditable {
                Text("Editing is disabled for the bundled sample. Open a writable todo.txt file to try the write path.")
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.TextToken.muted)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
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
            .scrollContentBackground(.hidden)
            .background(PlainTokens.Surface.canvas)
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
                showToast(ids.count == 1 ? "Task deleted · " : "\(ids.count) tasks deleted · ")
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
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    HStack(spacing: Spacing.md) {
                        Text(toastMessage)
                            .font(PlainType.toastMessage)
                        Button("Undo") {
                            undoManager?.undo()
                            dismissToast()
                        }
                        .font(PlainType.toastMessage)
                        .buttonStyle(.plain)
                        .underline()
                        .foregroundStyle(PlainTokens.TextToken.inverse)
                    }
                    .foregroundStyle(PlainTokens.TextToken.inverse)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(PlainTokens.Surface.toast, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .shadow(color: Color(hex: 0x2C2A28, opacity: 0.12), radius: PlainShadow.toastRadius, x: 0, y: PlainShadow.toastY)
                    .padding(.bottom, Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            HStack {
                Text(model.statusText)
                    .font(PlainType.statusBar)
                    .foregroundStyle(PlainTokens.TextToken.muted)
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .frame(height: Measurement.statusBarHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PlainTokens.Border.row)
                    .frame(height: Measurement.rowSeparatorThickness)
            }
        }
    }

    @Environment(\.plainFontSize) private var fontSize

    private func activeTaskRow(_ row: PlainShellModel.Row) -> some View {
        HStack(spacing: Spacing.sm) {
            // Completion circle
            Button {
                let wasCompleted = row.isCompleted
                if wasCompleted {
                    model.toggleCompletion(lineIdentity: row.id, undoManager: undoManager)
                } else {
                    // Show checkmark animation before completing
                    completingRowID = row.id
                    showToast("Task completed · ")
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(600))
                        model.toggleCompletion(lineIdentity: row.id, undoManager: undoManager)
                        try? await Task.sleep(for: .milliseconds(200))
                        if completingRowID == row.id {
                            completingRowID = nil
                        }
                    }
                }
            } label: {
                completionCircle(row: row)
                    .scaleEffect(completingRowID == row.id ? 1.15 : 1.0)
                    .animation(reduceMotion ? nil : Anim.completionCircle, value: completingRowID == row.id)
            }
            .buttonStyle(.borderless)
            .disabled(!model.isEditable)
            .accessibilityLabel(row.isCompleted ? "Mark incomplete" : "Mark complete")

            if editingRowID == row.id {
                // Inline edit mode
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextField("Edit line", text: $editingRawText)
                        .textFieldStyle(.roundedBorder)
                        .font(PlainType.taskBody(size: fontSize))
                        .focused($focusedField, equals: .inlineEdit)
                        .onSubmit {
                            commitInlineEdit(for: row.id)
                        }

                    HStack(spacing: Spacing.md) {
                        Button("Save") {
                            commitInlineEdit(for: row.id)
                        }
                        Button("Cancel") {
                            cancelInlineEdit()
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                    .font(PlainType.taskMeta)
                }
            } else {
                // Priority badge
                if let priority = row.priority {
                    Text(priority)
                        .font(PlainType.priorityBadge)
                        .foregroundStyle(priorityColor(priority))
                        .padding(.horizontal, Spacing.sm)
                        .frame(height: Measurement.priorityBadgeHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(priorityBgColor(priority))
                        )
                }

                // Task text with syntax highlighting
                SyntaxHighlightedText(
                    text: row.title,
                    query: model.activeSearchQuery,
                    strikethrough: row.isCompleted
                )

                Spacer()

                // Due date label
                if let dueLabel = row.dueLabel {
                    Text(dueLabel)
                        .font(row.isOverdue || row.isDueToday ? PlainType.taskDueDateUrgent : PlainType.taskDueDate)
                        .foregroundStyle(
                            row.isOverdue ? PlainTokens.Status.overdue
                            : row.isDueToday ? PlainTokens.Status.today
                            : PlainTokens.TextToken.muted
                        )
                }

                // Hover menu
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
                    Image(systemName: "ellipsis")
                        .foregroundStyle(PlainTokens.TextToken.secondary)
                        .font(PlainType.iconMedium)
                }
                .opacity(hoveredRowID == row.id ? Opacity.hoverMenu : 0.0)
                .animation(.easeOut(duration: Anim.fast), value: hoveredRowID == row.id)
                .disabled(!model.isEditable)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .frame(minHeight: Measurement.taskRowMinHeight)
        .onHover { isHovered in
            hoveredRowID = isHovered ? row.id : nil
        }
        .background {
            if highlightedRowID == row.id {
                Color.accentColor.opacity(Opacity.highlightRow)
            } else if hoveredRowID == row.id {
                PlainTokens.Surface.hover
            }
        }
        .contextMenu {
            Button(row.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                model.toggleCompletion(lineIdentity: row.id, undoManager: undoManager)
            }
            Button("Edit") {
                startInlineEdit(for: row)
            }
            Divider()
            Menu("Priority") {
                Button("A") { model.setPriority("A", lineIdentity: row.id, undoManager: undoManager) }
                Button("B") { model.setPriority("B", lineIdentity: row.id, undoManager: undoManager) }
                Button("C") { model.setPriority("C", lineIdentity: row.id, undoManager: undoManager) }
                Divider()
                Button("Clear") { model.setPriority(nil, lineIdentity: row.id, undoManager: undoManager) }
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
            Divider()
            Button("Delete", role: .destructive) {
                model.deleteRow(lineIdentity: row.id, undoManager: undoManager)
            }
        }
        .opacity(row.isCompleted ? Opacity.completedRow : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: Anim.normal), value: row.isCompleted)
        .overlay(alignment: .leading) {
            if model.selectedRowIDs.contains(row.id) {
                Rectangle()
                    .fill(PlainTokens.Selection.bar)
                    .frame(width: Measurement.selectionBarWidth)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(taskRowAccessibilityLabel(row))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PlainTokens.Border.row)
                .frame(height: Measurement.rowSeparatorThickness)
                .padding(.leading, Spacing.xl + Measurement.completionCircleDiameter + Spacing.sm)
        }
        .tag(row.id)
    }

    private func completionCircle(row: PlainShellModel.Row) -> some View {
        let isAnimatingComplete = completingRowID == row.id
        return ZStack {
            if row.isCompleted || isAnimatingComplete {
                Circle()
                    .fill(PlainTokens.Status.completed)
                    .frame(width: Measurement.completionCircleDiameter, height: Measurement.completionCircleDiameter)
                Image(systemName: "checkmark")
                    .font(PlainType.iconSmall)
                    .foregroundStyle(PlainTokens.TextToken.inverse)
            } else {
                Circle()
                    .stroke(
                        row.priority != nil ? priorityColor(row.priority!) : PlainTokens.TextToken.muted,
                        lineWidth: Measurement.rowSeparatorThickness * 4
                    )
                    .frame(width: Measurement.completionCircleDiameter, height: Measurement.completionCircleDiameter)
            }
        }
    }

    private var archiveDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("ARCHIVE")
                        .font(PlainType.sidebarSection)
                        .tracking(Tracking.sidebarSection)
                        .foregroundStyle(PlainTokens.Syntax.project)
                    Text(model.archiveDescription)
                        .font(PlainType.taskMeta)
                        .foregroundStyle(PlainTokens.TextToken.muted)
                }

                Spacer()

                Button("Back to tasks") {
                    model.selection = .inbox
                }
                .accessibilityIdentifier("plain.done.back")
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xxl)

            if model.hasActiveSearch && !isSearchPresented {
                searchFilterPill
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.lg)
            }

            List(model.visibleRows) { row in
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(PlainTokens.Status.completed)
                            .frame(width: Measurement.completionCircleDiameter, height: Measurement.completionCircleDiameter)
                        Image(systemName: "checkmark")
                            .font(PlainType.iconSmall)
                            .foregroundStyle(PlainTokens.TextToken.inverse)
                    }

                    if let priority = row.priority {
                        Text(priority)
                            .font(PlainType.priorityBadge)
                            .foregroundStyle(priorityColor(priority))
                            .padding(.horizontal, Spacing.sm)
                            .frame(height: Measurement.priorityBadgeHeight)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(priorityBgColor(priority))
                            )
                    }

                    SyntaxHighlightedText(
                        text: row.title,
                        query: model.activeSearchQuery,
                        strikethrough: true
                    )

                    Spacer()

                    if let dueLabel = row.dueLabel {
                        Text(dueLabel)
                            .font(PlainType.taskDueDate)
                            .foregroundStyle(PlainTokens.TextToken.muted)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .frame(minHeight: Measurement.taskRowMinHeight)
                .opacity(Opacity.completedRow)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(PlainTokens.Surface.canvas)
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
                    .font(PlainType.statusBar)
                    .foregroundStyle(PlainTokens.TextToken.muted)
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .frame(height: Measurement.statusBarHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PlainTokens.Border.row)
                    .frame(height: Measurement.rowSeparatorThickness)
            }
        }
    }

    private var scratchPadDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("SCRATCH PAD")
                        .font(PlainType.sidebarSection)
                        .tracking(Tracking.sidebarSection)
                        .foregroundStyle(PlainTokens.Syntax.project)

                    Text("Edit the full todo.txt directly. Save reparses and writes through the coordinated store.")
                        .font(PlainType.taskMeta)
                        .foregroundStyle(PlainTokens.TextToken.muted)
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
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)

            if model.hasExternalTodoConflict {
                conflictBanner
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
            }

            if let transientError = model.transientError {
                Text(transientError)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.Status.destructive)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
            }

            TextEditor(text: $scratchPadText)
                .font(PlainType.scratchPad)
                .padding(Spacing.xl)
                .scrollContentBackground(.hidden)
                .background(PlainTokens.Surface.input)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(PlainTokens.Border.input, lineWidth: 1)
                )
                .padding(Spacing.xl)

            HStack {
                Text(model.sourceDescription)
                    .font(PlainType.statusBar)
                    .foregroundStyle(PlainTokens.TextToken.muted)
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.lg)
        }
        .background(PlainTokens.Surface.canvas)
    }

    private var conflictBanner: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PlainTokens.Status.conflict)
                .font(PlainType.iconMedium)

            Text(model.externalTodoConflictMessage)
                .font(PlainType.taskBody)
                .foregroundStyle(PlainTokens.TextToken.primary)

            Spacer()

            HStack(spacing: Spacing.sm) {
                Button("Reload") {
                    model.reloadAfterConflict()
                }
                .font(PlainType.taskMeta)

                Text("|")
                    .foregroundStyle(PlainTokens.TextToken.muted)
                    .font(PlainType.taskMeta)

                Button("Keep Mine") {
                    model.keepMineAfterConflict()
                }
                .font(PlainType.taskMeta)

                Text("|")
                    .foregroundStyle(PlainTokens.TextToken.muted)
                    .font(PlainType.taskMeta)

                Button("View Diff") {
                    model.presentConflictDiff()
                }
                .font(PlainType.taskMeta)
                .accessibilityIdentifier("plain.conflict.viewDiff")
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(PlainTokens.Status.conflict.opacity(Opacity.bannerBg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
                showToast(ids.count == 1 ? "Task completed · " : "\(ids.count) tasks completed · ")
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
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Extend Selection Down") {
                guard focusedField == nil, editingRowID == nil else { return }
                model.extendSelection(by: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [.shift])

            Button("Extend Selection Up") {
                guard focusedField == nil, editingRowID == nil else { return }
                model.extendSelection(by: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [.shift])

            Button("Toggle Sidebar") {
                withAnimation {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                }
            }
            .keyboardShortcut("\\", modifiers: [.command])
        }
        .frame(width: 0, height: 0)
        .clipped()
        .opacity(0.001)
    }

    private var searchOverlay: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PlainTokens.TextToken.muted)
                .font(PlainType.iconLarge)

            TextField("Search tasks", text: $searchText)
                .textFieldStyle(.plain)
                .font(PlainType.taskBody)
                .focused($focusedField, equals: .search)
                .onSubmit {
                    dismissSearchOverlay(keepingFilter: true)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PlainTokens.TextToken.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: Measurement.searchOverlayWidth)
        .background(PlainTokens.Surface.input, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(PlainTokens.Border.input, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 6)
        .padding(.horizontal, Spacing.xxl)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .search
            }
        }
    }

    private var searchFilterPill: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PlainTokens.Syntax.project)
            Text("Showing results for \"\(model.activeSearchQuery)\"")
                .font(PlainType.taskMeta)
                .foregroundStyle(PlainTokens.TextToken.secondary)
            Button {
                clearSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(PlainTokens.TextToken.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(PlainTokens.Surface.hover, in: Capsule())
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

    private func showToast(_ message: String) {
        toastTask?.cancel()
        if reduceMotion {
            toastMessage = message
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                toastMessage = message
            }
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismissToast()
        }
    }

    private func submitNewTask() {
        let text = newTaskText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        trackRecentTags(in: text)
        model.addTask(rawText: text, undoManager: undoManager)
        newTaskText = ""
        autocompleteSuggestions = []
        autocompletePrefix = nil
        isDueDatePickerPresented = false
        flashHighlight(for: model.selectedRowID)
    }

    // MARK: - Tag Autocomplete (@context, +project) & Due Date Picker

    private static let recentContextsKey = "PlainRecentContexts"
    private static let recentProjectsKey = "PlainRecentProjects"
    private static let maxRecentTags = 10

    private func updateAutocompleteSuggestions(for text: String) {
        // Check for due: trigger first
        if text.hasSuffix("due:") || text.contains(" due:") {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("due:") {
                isDueDatePickerPresented = true
                dueDatePickerValue = Date()
                autocompleteSuggestions = []
                return
            }
        }

        isDueDatePickerPresented = false

        // Check for @context or +project token
        if let (range, prefix) = findActiveTagToken(in: text) {
            let partial = String(text[range]).lowercased()
            let allTags: [String]
            let recentKey: String

            if prefix == "@" {
                allTags = model.contextCounts.map(\.name)
                recentKey = Self.recentContextsKey
            } else {
                allTags = model.projectCounts.map(\.name)
                recentKey = Self.recentProjectsKey
            }

            guard !allTags.isEmpty else {
                autocompleteSuggestions = []
                autocompletePrefix = nil
                return
            }

            let recentTags = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
            let matching = partial.isEmpty ? allTags : allTags.filter { $0.lowercased().hasPrefix(partial) }

            guard !matching.isEmpty else {
                autocompleteSuggestions = []
                autocompletePrefix = nil
                return
            }

            let matchingSet = Set(matching)
            let recentMatching = recentTags.filter { matchingSet.contains($0) }
            let topRecent = Array(recentMatching.prefix(3))
            let topRecentSet = Set(topRecent)
            let remaining = matching.filter { !topRecentSet.contains($0) }.sorted()

            autocompleteSuggestions = topRecent + remaining
            autocompleteIndex = 0
            autocompletePrefix = Character(prefix)
        } else {
            autocompleteSuggestions = []
            autocompletePrefix = nil
        }
    }

    private func findActiveTagToken(in text: String) -> (Range<String.Index>, String)? {
        // Check both @ and + — whichever appears last and is active
        let atResult = findActivePrefixToken(in: text, prefix: "@")
        let plusResult = findActivePrefixToken(in: text, prefix: "+")

        switch (atResult, plusResult) {
        case let (.some(atRange), .some(plusRange)):
            // Return whichever is later in the string
            return atRange.lowerBound > plusRange.lowerBound ? (atRange, "@") : (plusRange, "+")
        case let (.some(atRange), .none):
            return (atRange, "@")
        case let (.none, .some(plusRange)):
            return (plusRange, "+")
        case (.none, .none):
            return nil
        }
    }

    private func findActivePrefixToken(in text: String, prefix: String) -> Range<String.Index>? {
        let prefixChar = prefix.first!
        guard let prefixIndex = text.lastIndex(of: prefixChar) else { return nil }
        let isAtStart = prefixIndex == text.startIndex
        let precededBySpace = !isAtStart && text[text.index(before: prefixIndex)] == " "
        guard isAtStart || precededBySpace else { return nil }

        let afterPrefix = text.index(after: prefixIndex)
        let rest = text[afterPrefix...]
        if rest.contains(" ") { return nil }

        return afterPrefix..<text.endIndex
    }

    private func acceptAutocompleteSuggestion(_ suggestion: String) {
        guard let (range, prefix) = findActiveTagToken(in: newTaskText) else { return }
        let prefixIndex = newTaskText.index(before: range.lowerBound)
        let before = newTaskText[newTaskText.startIndex..<prefixIndex]
        newTaskText = before + "\(prefix)\(suggestion) "
        autocompleteSuggestions = []
        autocompletePrefix = nil
    }

    private func isRecentTag(_ tag: String, prefix: Character?) -> Bool {
        let key = prefix == "+" ? Self.recentProjectsKey : Self.recentContextsKey
        let recent = UserDefaults.standard.stringArray(forKey: key) ?? []
        return recent.prefix(3).contains(tag)
    }

    private func trackRecentTags(in text: String) {
        let words = text.split(separator: " ")
        var contexts: [String] = []
        var projects: [String] = []

        for word in words {
            if word.hasPrefix("@"), word.count > 1 {
                contexts.append(String(word.dropFirst()))
            } else if word.hasPrefix("+"), word.count > 1 {
                projects.append(String(word.dropFirst()))
            }
        }

        if !contexts.isEmpty {
            updateRecentList(key: Self.recentContextsKey, newItems: contexts)
        }
        if !projects.isEmpty {
            updateRecentList(key: Self.recentProjectsKey, newItems: projects)
        }
    }

    private func updateRecentList(key: String, newItems: [String]) {
        var recent = UserDefaults.standard.stringArray(forKey: key) ?? []
        for item in newItems.reversed() {
            recent.removeAll { $0 == item }
            recent.insert(item, at: 0)
        }
        if recent.count > Self.maxRecentTags {
            recent = Array(recent.prefix(Self.maxRecentTags))
        }
        UserDefaults.standard.set(recent, forKey: key)
    }

    private func insertDueDate(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        // Replace "due:" at the end of text with "due:YYYY-MM-DD "
        if let range = newTaskText.range(of: "due:", options: .backwards) {
            newTaskText = newTaskText[newTaskText.startIndex..<range.lowerBound] + "due:\(dateString) "
        } else {
            newTaskText += " due:\(dateString) "
        }

        isDueDatePickerPresented = false
    }

    private func flashHighlight(for id: LineIdentity?) {
        guard let id else { return }
        if reduceMotion {
            highlightedRowID = id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                highlightedRowID = nil
            }
        } else {
            withAnimation(.easeIn(duration: 0.15)) {
                highlightedRowID = id
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeOut(duration: 0.5)) {
                    if highlightedRowID == id {
                        highlightedRowID = nil
                    }
                }
            }
        }
    }

    private func dismissToast() {
        toastTask?.cancel()
        toastTask = nil
        if reduceMotion {
            toastMessage = nil
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                toastMessage = nil
            }
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
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Resolve Conflict")
                    .font(PlainType.sidebarLabel)
                    .foregroundStyle(PlainTokens.TextToken.primary)
                Text("Compare the disk version with your current \(diff.draftTitle.lowercased()) before deciding which one to keep.")
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.TextToken.secondary)
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
        .padding(Spacing.xxl)
        .frame(minWidth: 880, minHeight: 520)
        .accessibilityIdentifier("plain.conflict.diffSheet")
    }

    private func diffColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(PlainType.sidebarLabel)
                .foregroundStyle(PlainTokens.TextToken.primary)

            TextEditor(text: .constant(text))
                .font(PlainType.scratchPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background(PlainTokens.Surface.input)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(PlainTokens.Border.input, lineWidth: 1)
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
            .background(highlighted ? PlainTokens.Search.highlight : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

private func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "A": return PlainTokens.Priority.a
    case "B": return PlainTokens.Priority.b
    case "C": return PlainTokens.Priority.c
    default: return PlainTokens.Priority.low
    }
}

private func priorityBgColor(_ priority: String) -> Color {
    switch priority {
    case "A": return PlainTokens.Priority.aBg
    case "B": return PlainTokens.Priority.bBg
    case "C": return PlainTokens.Priority.cBg
    default: return PlainTokens.Priority.lowBg
    }
}

private struct SyntaxHighlightedText: View {
    let text: String
    let query: String
    var strikethrough = false
    @Environment(\.plainFontSize) private var fontSize

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
            .italic(strikethrough)
            .padding(.horizontal, highlighted ? 2 : 0)
            .background(highlighted ? PlainTokens.Search.highlight : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    private func coloredAttributedString(_ segment: String) -> AttributedString {
        var result = AttributedString()
        let words = segment.split(separator: " ", omittingEmptySubsequences: false)
        let baseFont = PlainType.taskBody(size: fontSize)
        let tagsFont = PlainType.taskTags(size: fontSize)
        let metaFont = PlainType.taskMeta

        for (i, word) in words.enumerated() {
            if i > 0 {
                var space = AttributedString(" ")
                space.font = baseFont
                space.foregroundColor = PlainTokens.TextToken.primary
                result.append(space)
            }

            let w = String(word)
            if w.hasPrefix("+") && w.count > 1 {
                var attr = AttributedString(w)
                attr.font = tagsFont
                attr.foregroundColor = PlainTokens.Syntax.project
                result.append(attr)
            } else if w.hasPrefix("@") && w.count > 1 {
                var attr = AttributedString(w)
                attr.font = tagsFont
                attr.foregroundColor = PlainTokens.Syntax.context
                result.append(attr)
            } else if w.contains(":") && !w.hasPrefix(":") && !w.hasSuffix(":") && w.count > 2 {
                var attr = AttributedString(w)
                attr.font = metaFont
                attr.foregroundColor = PlainTokens.Syntax.keyValue
                result.append(attr)
            } else {
                var attr = AttributedString(w)
                attr.font = baseFont
                attr.foregroundColor = PlainTokens.TextToken.primary
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
        HStack(spacing: Spacing.md) {
            Text(title.uppercased())
                .font(PlainType.groupHeader)
                .tracking(Tracking.groupHeader)
                .foregroundStyle(PlainTokens.Syntax.project)
            Rectangle()
                .fill(PlainTokens.Border.section)
                .frame(height: 1)
        }
        .frame(height: Measurement.groupHeaderHeight)
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
        VStack(spacing: Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(PlainTokens.TextToken.muted)

            Text(title)
                .font(PlainType.sidebarLabel)
                .foregroundStyle(PlainTokens.TextToken.secondary)

            Text(message)
                .font(PlainType.taskMeta)
                .foregroundStyle(PlainTokens.TextToken.muted)
                .multilineTextAlignment(.center)

            if let primaryActionTitle, let primaryAction {
                HStack(spacing: Spacing.lg) {
                    Button(primaryActionTitle, action: primaryAction)
                        .accessibilityIdentifier(primaryActionAccessibilityIdentifier ?? "")

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
                            .accessibilityIdentifier(secondaryActionAccessibilityIdentifier ?? "")
                    }
                }
                .padding(.top, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xxl)
    }
}

private struct SidebarSectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(PlainType.sidebarSection)
            .tracking(Tracking.sidebarSection)
            .foregroundStyle(PlainTokens.Syntax.project)
    }
}

private struct SidebarRow: View {
    let title: String
    let count: Int
    var isOverdue = false

    var body: some View {
        HStack {
            Text(title)
                .font(PlainType.sidebarLabel)
            Spacer()
            Text("\(count)")
                .font(PlainType.sidebarCount)
                .foregroundStyle(isOverdue ? PlainTokens.Status.overdue : PlainTokens.TextToken.muted)
        }
        .frame(height: Measurement.sidebarItemHeight)
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
        /// 0 = overdue, 1 = today, 2 = upcoming, 3 = none
        let dueBucketRank: Int

        var isDueToday: Bool { dueBucketRank == 1 }
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

    var currentFileURL: URL? {
        currentSourceURL
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

    var windowTitle: String {
        if let url = currentSourceURL {
            return url.lastPathComponent
        }
        return "Plain"
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
            store.createBackupBeforeWrite = preferences.createBackup
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

    func createNewFile() {
        let panel = NSSavePanel()
        panel.title = "Create a new todo.txt"
        panel.nameFieldStringValue = "todo.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try Data().write(to: url)
            open(url: url)
        } catch {
            present(error: error)
        }
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

    func extendSelection(by offset: Int) {
        guard !visibleRows.isEmpty else { return }

        guard let selectedRowID,
              let currentIndex = visibleRows.firstIndex(where: { $0.id == selectedRowID })
        else {
            selectedRowID = visibleRows.first?.id
            return
        }

        let nextIndex = max(0, min(visibleRows.count - 1, currentIndex + offset))
        let nextID = visibleRows[nextIndex].id
        selectedRowIDs.insert(nextID)
        self.selectedRowID = nextID
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
            if FileManager.default.fileExists(atPath: restoredURL.path) {
                return (restoredURL, true, true, deepLinkURL)
            } else {
                sessionRestore.setSourceURL(nil)
                sessionRestore.setSelection(nil)
            }
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
        var text = DatePhraseParser.preview(for: rawText, referenceDate: referenceDate)?.transformedText ?? rawText

        // Apply default priority if none specified and user set a default
        if let defaultPriority = preferences.defaultPriority {
            let parsedLine = TodoParser.parseLine(text, lineNumber: 0, originalLineEnding: nil)
            if let task = parsedLine.task, !task.isCompleted, task.priority == nil {
                text = "(\(defaultPriority)) \(text)"
            }
        }

        guard preferences.automaticallyAddCreationDate else {
            return text
        }

        return applyingCreationDateIfNeeded(to: text, referenceDate: referenceDate)
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
        case .dueDate:
            return Dictionary(grouping: rows) { dueDateGroupTitle(for: $0, relativeTo: Date()) }
                .sorted { lhs, rhs in dueDateGroupRank(lhs.key) < dueDateGroupRank(rhs.key) }
                .map { title, groupedRows in
                    RowGroup(id: title, title: title, rows: groupedRows)
                }
        case .context:
            return Dictionary(grouping: rows) { firstTag(from: $0.rawText, prefix: "@") ?? "No Context" }
                .sorted { lhs, rhs in
                    if lhs.key == "No Context" { return false }
                    if rhs.key == "No Context" { return true }
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                .map { title, groupedRows in
                    RowGroup(id: title, title: title == "No Context" ? title : "@\(title)", rows: groupedRows)
                }
        case .project:
            return Dictionary(grouping: rows) { firstTag(from: $0.rawText, prefix: "+") ?? "No Project" }
                .sorted { lhs, rhs in
                    if lhs.key == "No Project" { return false }
                    if rhs.key == "No Project" { return true }
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                .map { title, groupedRows in
                    RowGroup(id: title, title: title == "No Project" ? title : "+\(title)", rows: groupedRows)
                }
        }
    }

    private func firstTag(from rawText: String, prefix: String) -> String? {
        rawText.split(separator: " ")
            .first { $0.hasPrefix(prefix) && $0.count > 1 }
            .map { String($0.dropFirst()) }
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

    private func dueDateGroupTitle(for row: Row, relativeTo now: Date) -> String {
        switch row.dueBucketRank {
        case 0:
            return "Overdue"
        case 1:
            return "Today"
        case 2:
            return "Upcoming"
        default:
            return "No Due Date"
        }
    }

    private func dueDateGroupRank(_ title: String) -> Int {
        switch title {
        case "Overdue":
            return 0
        case "Today":
            return 1
        case "Upcoming":
            return 2
        case "No Due Date":
            return 3
        default:
            return 4
        }
    }

    private func dueBucketSortRank(_ bucket: IndexedTask.DueBucket) -> Int {
        switch bucket {
        case .overdue:
            return 0
        case .today:
            return 1
        case .upcoming:
            return 2
        case .none:
            return 3
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
                    isOverdue: indexedTask.dueBucket(relativeTo: Date()) == .overdue,
                    dueBucketRank: dueBucketSortRank(indexedTask.dueBucket(relativeTo: Date()))
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
                isOverdue: false,
                dueBucketRank: 3
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
            isOverdue: indexedTask.dueBucket(relativeTo: Date()) == .overdue,
            dueBucketRank: dueBucketSortRank(indexedTask.dueBucket(relativeTo: Date()))
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
        case .dueDate:
            let lhsBucket = lhs.dueBucket(relativeTo: Date())
            let rhsBucket = rhs.dueBucket(relativeTo: Date())
            let lhsRank = dueBucketSortRank(lhsBucket)
            let rhsRank = dueBucketSortRank(rhsBucket)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if let lhsDate = lhs.parsedDueDate, let rhsDate = rhs.parsedDueDate, lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.index < rhs.index
        case .alphabetical:
            let comparison = lhs.task.body.localizedCaseInsensitiveCompare(rhs.task.body)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return lhs.index < rhs.index
        case .context:
            let lhsContext = lhs.task.contexts.sorted().first ?? ""
            let rhsContext = rhs.task.contexts.sorted().first ?? ""
            if lhsContext != rhsContext {
                if lhsContext.isEmpty { return false }
                if rhsContext.isEmpty { return true }
                let cmp = lhsContext.localizedCaseInsensitiveCompare(rhsContext)
                if cmp != .orderedSame { return cmp == .orderedAscending }
            }
            return lhs.index < rhs.index
        case .project:
            let lhsProject = lhs.task.projects.sorted().first ?? ""
            let rhsProject = rhs.task.projects.sorted().first ?? ""
            if lhsProject != rhsProject {
                if lhsProject.isEmpty { return false }
                if rhsProject.isEmpty { return true }
                let cmp = lhsProject.localizedCaseInsensitiveCompare(rhsProject)
                if cmp != .orderedSame { return cmp == .orderedAscending }
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
                isOverdue: false,
                dueBucketRank: 3
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
            case .upcoming:
                guard let date = parsedDueDate else { return due }
                let calendar = Calendar(identifier: .gregorian)
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
                   calendar.isDate(date, inSameDayAs: tomorrow) {
                    return "Tomorrow"
                }
                let formatter = DateFormatter()
                formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
                return formatter.string(from: date)
            case .none:
                return due
            }
        }

        private var dueMetadataValue: String? {
            task.metadata.first { $0.key == "due" }?.value
        }

        var parsedDueDate: Date? {
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
import PlainCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct PlainApp: App {
    var body: some Scene {
        WindowGroup {
            PlainShellView()
        }
    }
}

private struct PlainShellView: View {
    @StateObject private var model = PlainShellModel()
    @State private var isFileImporterPresented = false
    @State private var newTaskText = ""
    @State private var editingRowID: LineIdentity?
    @State private var editingRawText = ""
    @FocusState private var isEditingFieldFocused: Bool

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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Open") {
                    isFileImporterPresented = true
                }

                Button("Use Sample") {
                    model.loadBundledSample()
                }
            }
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
    }

    private var onboardingView: some View {
        PlaceholderCard(
            title: "Point Plain at your todo.txt file.",
            systemImage: "text.page",
            message: "Start with an existing todo.txt file, or load the bundled sample while the bootstrap shell is still read-only.",
            primaryActionTitle: "Open an existing file",
            primaryAction: { isFileImporterPresented = true },
            secondaryActionTitle: "Use bundled sample",
            secondaryAction: { model.loadBundledSample() }
        )
    }

    private var detailView: some View {
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

            HStack(spacing: 12) {
                TextField("Add a task...", text: $newTaskText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!model.isEditable)
                    .onSubmit {
                        guard !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }

                        model.addTask(rawText: newTaskText)
                        newTaskText = ""
                    }

                Button("Add") {
                    guard !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }

                    model.addTask(rawText: newTaskText)
                    newTaskText = ""
                }
                .disabled(!model.isEditable || newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if !model.isEditable {
                Text("Editing is disabled for the bundled sample. Open a writable todo.txt file to try the write path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            List(model.visibleRows) { row in
                HStack {
                    Button {
                        model.toggleCompletion(lineIdentity: row.id)
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
                                .focused($isEditingFieldFocused)
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

                                Text(row.title)
                                    .font(.body)
                                    .strikethrough(row.isCompleted)

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
                                        model.setPriority("A", lineIdentity: row.id)
                                    }
                                    Button("Priority B") {
                                        model.setPriority("B", lineIdentity: row.id)
                                    }
                                    Button("Priority C") {
                                        model.setPriority("C", lineIdentity: row.id)
                                    }
                                    Button("Clear Priority") {
                                        model.setPriority(nil, lineIdentity: row.id)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        model.deleteRow(lineIdentity: row.id)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .disabled(!model.isEditable)
                            }

                            Text(row.rawText)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onExitCommand {
                cancelInlineEdit()
            }
            .overlay {
                if model.visibleRows.isEmpty {
                    PlaceholderCard(
                        title: "Nothing here yet",
                        systemImage: "line.3.horizontal.decrease.circle",
                        message: "This view is empty for the current filter."
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

    private func startInlineEdit(for row: PlainShellModel.Row) {
        guard model.isEditable else {
            return
        }

        editingRowID = row.id
        editingRawText = row.rawText
        isEditingFieldFocused = true
    }

    private func commitInlineEdit(for identity: LineIdentity) {
        let trimmed = editingRawText.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            model.deleteRow(lineIdentity: identity)
            cancelInlineEdit()
            return
        }

        model.replaceLine(rawText: editingRawText, lineIdentity: identity)
        cancelInlineEdit()
    }

    private func cancelInlineEdit() {
        editingRowID = nil
        editingRawText = ""
        isEditingFieldFocused = false
    }
}

private struct PlaceholderCard: View {
    let title: String
    let systemImage: String
    let message: String
    var primaryActionTitle: String?
    var primaryAction: (() -> Void)?
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

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

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
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

private enum SidebarSelection: Hashable {
    case inbox
    case today
    case overdue
    case done
    case project(String)
    case context(String)
}

@MainActor
private final class PlainShellModel: ObservableObject {
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
        let isCompleted: Bool
        let dueLabel: String?
        let isOverdue: Bool
    }

    @Published var selection: SidebarSelection = .inbox
    @Published private(set) var snapshot: TodoFileSnapshot?
    @Published private(set) var visibleRows: [Row] = []
    @Published private(set) var sourceDescription = "Loading sample snapshot"
    @Published private(set) var loadError: String?
    @Published private(set) var transientError: String?
    @Published private(set) var inboxCount = 0
    @Published private(set) var todayCount = 0
    @Published private(set) var overdueCount = 0
    @Published private(set) var doneCount = 0
    @Published private(set) var projectCounts: [TagCount] = []
    @Published private(set) var contextCounts: [TagCount] = []

    private var hasLoaded = false
    private let userDefaults = UserDefaults.standard
    private let persistedFilePathKey = "PlainBootstrapSelectedFilePath"
    private var store: CoordinatedTodoStore?
    private var isPersistedSourceEditable = false

    var isEditable: Bool {
        isPersistedSourceEditable
    }

    var statusText: String {
        "\(inboxCount) tasks · \(doneCount) done · \(overdueCount) overdue"
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
            store.onSnapshotChange = { [weak self] result in
                DispatchQueue.main.async {
                    self?.applyReloadResult(result, sourceURL: url, persistSelection: persistSelection)
                }
            }
            store.startMonitoring()

            let snapshot = try store.load()
            self.store = store
            apply(snapshot: snapshot, sourceURL: url, persistSelection: persistSelection)
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
        visibleRows = []
        projectCounts = []
        contextCounts = []
        inboxCount = 0
        todayCount = 0
        overdueCount = 0
        doneCount = 0
        sourceDescription = "Bootstrap shell"
        loadError = error.localizedDescription
        transientError = nil
    }

    func addTask(rawText: String) {
        guard let store else {
            return
        }

        do {
            _ = try store.appendTask(rawText: rawText)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func toggleCompletion(lineIdentity: LineIdentity) {
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

        do {
            _ = try store.toggleCompletion(lineIdentity: lineIdentity, completionDate: TodoDate(year: year, month: month, day: day))
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func setPriority(_ priority: Character?, lineIdentity: LineIdentity) {
        guard let store else {
            return
        }

        do {
            _ = try store.setPriority(priority, lineIdentity: lineIdentity)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func deleteRow(lineIdentity: LineIdentity) {
        guard let store else {
            return
        }

        do {
            _ = try store.deleteTask(lineIdentity: lineIdentity)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    func replaceLine(rawText: String, lineIdentity: LineIdentity) {
        guard let store else {
            return
        }

        do {
            _ = try store.replaceLine(rawText: rawText, lineIdentity: lineIdentity)
            transientError = nil
        } catch {
            transientError = error.localizedDescription
        }
    }

    private func resolveInitialSourceURL() -> URL? {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let firstArgument = arguments.first {
            return URL(fileURLWithPath: NSString(string: firstArgument).expandingTildeInPath)
        }

        if let persistedPath = userDefaults.string(forKey: persistedFilePathKey) {
            return URL(fileURLWithPath: persistedPath)
        }

        return nil
    }

    private func bundledSampleURL() -> URL? {
        Bundle.module.url(forResource: "sample", withExtension: "txt", subdirectory: "Resources")
    }

    private func applyReloadResult(
        _ result: Result<TodoFileSnapshot, Error>,
        sourceURL: URL,
        persistSelection: Bool
    ) {
        switch result {
        case let .success(snapshot):
            apply(snapshot: snapshot, sourceURL: sourceURL, persistSelection: persistSelection)
        case let .failure(error):
            present(error: error)
        }
    }

    private func apply(snapshot: TodoFileSnapshot, sourceURL: URL, persistSelection: Bool) {
        self.snapshot = snapshot
        self.loadError = nil
        self.transientError = nil
        self.isPersistedSourceEditable = persistSelection && FileManager.default.isWritableFile(atPath: sourceURL.path)

        if persistSelection {
            userDefaults.set(sourceURL.path, forKey: persistedFilePathKey)
        }

        let indexedTasks = snapshot.lines.enumerated().compactMap { index, line -> IndexedTask? in
            guard let task = line.task else {
                return nil
            }

            return IndexedTask(index: index, line: line, task: task)
        }

        let incompleteTasks = indexedTasks.filter { !$0.task.isCompleted }
        let completedTasks = indexedTasks.filter(\.task.isCompleted)

        inboxCount = incompleteTasks.count
        todayCount = incompleteTasks.filter { $0.dueBucket(relativeTo: Date()) == .today }.count
        overdueCount = incompleteTasks.filter { $0.dueBucket(relativeTo: Date()) == .overdue }.count
        doneCount = completedTasks.count
        projectCounts = buildTagCounts(from: incompleteTasks, keyPath: \.task.projects)
        contextCounts = buildTagCounts(from: incompleteTasks, keyPath: \.task.contexts)
        sourceDescription = sourceLabel(for: sourceURL, snapshot: snapshot)
        visibleRows = buildVisibleRows(from: snapshot, tasks: indexedTasks)
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

    private func buildVisibleRows(from snapshot: TodoFileSnapshot, tasks: [IndexedTask]) -> [Row] {
        snapshot.lines.enumerated().compactMap { index, line in
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
                isCompleted: false,
                dueLabel: nil,
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
            return indexedTask.task.isCompleted
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
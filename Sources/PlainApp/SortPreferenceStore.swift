import Foundation

enum TaskSortMode: String, CaseIterable, Identifiable {
    case fileOrder
    case priority
    case creationDate
    case dueDate
    case alphabetical
    case context
    case project

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fileOrder:
            return "File Order"
        case .priority:
            return "Priority"
        case .creationDate:
            return "Creation Date"
        case .dueDate:
            return "Due Date"
        case .alphabetical:
            return "Alphabetical"
        case .context:
            return "Context"
        case .project:
            return "Project"
        }
    }

    var next: TaskSortMode {
        switch self {
        case .fileOrder:
            return .priority
        case .priority:
            return .creationDate
        case .creationDate:
            return .dueDate
        case .dueDate:
            return .alphabetical
        case .alphabetical:
            return .context
        case .context:
            return .project
        case .project:
            return .fileOrder
        }
    }
}

final class SortPreferenceStore {
    private let userDefaults: UserDefaults
    private let prefix = "PlainSortMode."

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func sortMode(for selection: SidebarSelection) -> TaskSortMode {
        guard selection != .done,
              let rawValue = userDefaults.string(forKey: prefix + selection.sortPreferenceKey),
              let sortMode = TaskSortMode(rawValue: rawValue)
        else {
            return .fileOrder
        }

        return sortMode
    }

    func setSortMode(_ sortMode: TaskSortMode, for selection: SidebarSelection) {
        guard selection != .done else {
            return
        }

        userDefaults.set(sortMode.rawValue, forKey: prefix + selection.sortPreferenceKey)
    }
}

extension SidebarSelection {
    var sortPreferenceKey: String {
        switch self {
        case .inbox:
            return "inbox"
        case .today:
            return "today"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case let .project(project):
            return "project.\(project)"
        case let .context(context):
            return "context.\(context)"
        }
    }
}
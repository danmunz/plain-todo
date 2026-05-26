import Foundation

final class SessionRestoreStore {
    private let userDefaults: UserDefaults
    private let sourcePathKey = "PlainSessionRestoreSourcePath"
    private let selectionKey = "PlainSessionRestoreSelection"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func restoredSourceURL() -> URL? {
        guard let path = userDefaults.string(forKey: sourcePathKey) else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    func setSourceURL(_ url: URL?) {
        if let url {
            userDefaults.set(url.path, forKey: sourcePathKey)
        } else {
            userDefaults.removeObject(forKey: sourcePathKey)
        }
    }

    func restoredSelection() -> SidebarSelection? {
        guard let rawValue = userDefaults.string(forKey: selectionKey) else {
            return nil
        }

        return SidebarSelection(sessionRestoreValue: rawValue)
    }

    func setSelection(_ selection: SidebarSelection?) {
        if let selection {
            userDefaults.set(selection.sessionRestoreValue, forKey: selectionKey)
        } else {
            userDefaults.removeObject(forKey: selectionKey)
        }
    }
}

extension SidebarSelection {
    var sessionRestoreValue: String {
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
            return "project:\(project)"
        case let .context(context):
            return "context:\(context)"
        }
    }

    init?(sessionRestoreValue: String) {
        switch sessionRestoreValue {
        case "inbox":
            self = .inbox
        case "today":
            self = .today
        case "overdue":
            self = .overdue
        case "done":
            self = .done
        default:
            if sessionRestoreValue.hasPrefix("project:") {
                self = .project(String(sessionRestoreValue.dropFirst("project:".count)))
            } else if sessionRestoreValue.hasPrefix("context:") {
                self = .context(String(sessionRestoreValue.dropFirst("context:".count)))
            } else {
                return nil
            }
        }
    }
}
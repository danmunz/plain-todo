import Foundation

struct PlainDeepLinkRoute {
    let selection: SidebarSelection

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare("plain") == .orderedSame else {
            return nil
        }

        switch url.host?.lowercased() {
        case "inbox":
            selection = .inbox
        case "today":
            selection = .today
        case "overdue":
            selection = .overdue
        case "done":
            selection = .done
        case "project":
            let project = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !project.isEmpty else {
                return nil
            }
            selection = .project(project)
        case "context":
            let context = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !context.isEmpty else {
                return nil
            }
            selection = .context(context)
        default:
            return nil
        }
    }
}
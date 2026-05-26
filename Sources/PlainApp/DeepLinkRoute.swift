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
            let project = Self.decodedSegment(from: url.path)
            guard !project.isEmpty else {
                return nil
            }
            selection = .project(project)
        case "context":
            let context = Self.decodedSegment(from: url.path)
            guard !context.isEmpty else {
                return nil
            }
            selection = .context(context)
        default:
            return nil
        }
    }

    private static func decodedSegment(from rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.removingPercentEncoding ?? trimmed
    }
}
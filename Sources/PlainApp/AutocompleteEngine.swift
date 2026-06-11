import Foundation

@MainActor
final class AutocompleteEngine: ObservableObject {
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var activePrefix: Character?
    @Published var isDueDatePickerPresented: Bool = false
    @Published var dueDatePickerValue: Date = Date()

    private let tagProvider: () -> (projects: [String], contexts: [String])

    private static let recentContextsKey = "PlainRecentContexts"
    private static let recentProjectsKey = "PlainRecentProjects"
    private static let maxRecentTags = 10

    init(tagProvider: @escaping () -> (projects: [String], contexts: [String])) {
        self.tagProvider = tagProvider
    }

    var hasSuggestions: Bool { !suggestions.isEmpty }

    func update(for text: String) {
        if text.hasSuffix("due:") || text.contains(" due:") {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("due:") {
                isDueDatePickerPresented = true
                dueDatePickerValue = Date()
                suggestions = []
                return
            }
        }

        isDueDatePickerPresented = false

        if let (range, prefix) = findActiveTagToken(in: text) {
            let partial = String(text[range]).lowercased()
            let tags = tagProvider()
            let allTags: [String]
            let recentKey: String

            if prefix == "@" {
                allTags = tags.contexts
                recentKey = Self.recentContextsKey
            } else {
                allTags = tags.projects
                recentKey = Self.recentProjectsKey
            }

            guard !allTags.isEmpty else {
                suggestions = []
                activePrefix = nil
                return
            }

            let recentTags = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
            let matching = partial.isEmpty ? allTags : allTags.filter { $0.lowercased().hasPrefix(partial) }

            guard !matching.isEmpty else {
                suggestions = []
                activePrefix = nil
                return
            }

            let matchingSet = Set(matching)
            let recentMatching = recentTags.filter { matchingSet.contains($0) }
            let topRecent = Array(recentMatching.prefix(3))
            let topRecentSet = Set(topRecent)
            let remaining = matching.filter { !topRecentSet.contains($0) }.sorted()

            suggestions = topRecent + remaining
            selectedIndex = 0
            activePrefix = Character(prefix)
        } else {
            suggestions = []
            activePrefix = nil
        }
    }

    func moveUp() {
        guard hasSuggestions else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveDown() {
        guard hasSuggestions else { return }
        selectedIndex = min(suggestions.count - 1, selectedIndex + 1)
    }

    func acceptSuggestion(in text: inout String) {
        guard hasSuggestions else { return }
        let suggestion = suggestions[selectedIndex]
        guard let (range, prefix) = findActiveTagToken(in: text) else { return }
        let prefixIndex = text.index(before: range.lowerBound)
        let before = text[text.startIndex..<prefixIndex]
        text = before + "\(prefix)\(suggestion) "
        dismiss()
    }

    func dismiss() {
        suggestions = []
        activePrefix = nil
    }

    func insertDueDate(_ date: Date, into text: inout String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        if let range = text.range(of: "due:", options: .backwards) {
            text = text[text.startIndex..<range.lowerBound] + "due:\(dateString) "
        } else {
            text += " due:\(dateString) "
        }

        isDueDatePickerPresented = false
    }

    func isRecentTag(_ tag: String) -> Bool {
        let key = activePrefix == "+" ? Self.recentProjectsKey : Self.recentContextsKey
        let recent = UserDefaults.standard.stringArray(forKey: key) ?? []
        return recent.prefix(3).contains(tag)
    }

    func trackRecentTags(in text: String) {
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

    private func findActiveTagToken(in text: String) -> (Range<String.Index>, String)? {
        let atResult = findActivePrefixToken(in: text, prefix: "@")
        let plusResult = findActivePrefixToken(in: text, prefix: "+")

        switch (atResult, plusResult) {
        case let (.some(atRange), .some(plusRange)):
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
}

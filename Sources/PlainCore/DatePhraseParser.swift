import Foundation

public struct DatePhrasePreview: Equatable, Sendable {
    public let sourcePhrase: String
    public let dueDate: TodoDate
    public let transformedText: String

    public init(sourcePhrase: String, dueDate: TodoDate, transformedText: String) {
        self.sourcePhrase = sourcePhrase
        self.dueDate = dueDate
        self.transformedText = transformedText
    }
}

public enum DatePhraseParser {
    private static let weekdayNames = [
        "sunday": 1,
        "monday": 2,
        "tuesday": 3,
        "wednesday": 4,
        "thursday": 5,
        "friday": 6,
        "saturday": 7
    ]

    private static let monthNames = [
        "january": 1,
        "february": 2,
        "march": 3,
        "april": 4,
        "may": 5,
        "june": 6,
        "july": 7,
        "august": 8,
        "september": 9,
        "october": 10,
        "november": 11,
        "december": 12
    ]

    public static func preview(
        for rawText: String,
        referenceDate: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DatePhrasePreview? {
        guard !rawText.isEmpty,
              !rawText.localizedCaseInsensitiveContains("due:")
        else {
            return nil
        }

        guard let resolvedPhrase = resolvePhrase(in: rawText, referenceDate: referenceDate, calendar: calendar) else {
            return nil
        }

        var transformedText = rawText
        transformedText.replaceSubrange(resolvedPhrase.range, with: "due:\(resolvedPhrase.dueDate)")
        transformedText = transformedText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return DatePhrasePreview(
            sourcePhrase: String(rawText[resolvedPhrase.range]),
            dueDate: resolvedPhrase.dueDate,
            transformedText: transformedText
        )
    }

    private struct ResolvedPhrase {
        let range: Range<String.Index>
        let dueDate: TodoDate
    }

    private static func resolvePhrase(
        in rawText: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> ResolvedPhrase? {
        if let range = rawText.range(of: "end of month", options: [.caseInsensitive, .diacriticInsensitive]),
           let dueDate = endOfMonth(referenceDate: referenceDate, calendar: calendar)
        {
            return ResolvedPhrase(range: range, dueDate: dueDate)
        }

        if let range = wholeWordRange("tomorrow", in: rawText),
           let dueDate = offsetDate(referenceDate: referenceDate, dayOffset: 1, calendar: calendar)
        {
            return ResolvedPhrase(range: range, dueDate: dueDate)
        }

        if let range = wholeWordRange("today", in: rawText),
           let dueDate = todoDate(from: referenceDate, calendar: calendar)
        {
            return ResolvedPhrase(range: range, dueDate: dueDate)
        }

        if let match = firstRegexMatch(in: rawText, pattern: #"\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#),
           let weekday = weekdayNames[match.captures[0].lowercased()],
           let dueDate = nextWeekday(weekday, referenceDate: referenceDate, calendar: calendar)
        {
            return ResolvedPhrase(range: match.range, dueDate: dueDate)
        }

        if let match = firstRegexMatch(in: rawText, pattern: #"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#),
           let weekday = weekdayNames[match.captures[0].lowercased()],
           let dueDate = nextWeekday(weekday, referenceDate: referenceDate, calendar: calendar)
        {
            return ResolvedPhrase(range: match.range, dueDate: dueDate)
        }

        if let match = firstRegexMatch(in: rawText, pattern: #"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})\b"#),
           let month = monthNames[match.captures[0].lowercased()],
           let day = Int(match.captures[1]),
           let dueDate = monthDay(month: month, day: day, referenceDate: referenceDate, calendar: calendar)
        {
            return ResolvedPhrase(range: match.range, dueDate: dueDate)
        }

        return nil
    }

    private static func wholeWordRange(_ phrase: String, in rawText: String) -> Range<String.Index>? {
        firstRegexMatch(in: rawText, pattern: #"\b"# + NSRegularExpression.escapedPattern(for: phrase) + #"\b"#)?.range
    }

    private static func offsetDate(referenceDate: Date, dayOffset: Int, calendar: Calendar) -> TodoDate? {
        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: referenceDate)) else {
            return nil
        }

        return todoDate(from: date, calendar: calendar)
    }

    private static func nextWeekday(_ weekday: Int, referenceDate: Date, calendar: Calendar) -> TodoDate? {
        let start = calendar.startOfDay(for: referenceDate)
        for offset in 1...14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }

            if calendar.component(.weekday, from: candidate) == weekday {
                return todoDate(from: candidate, calendar: calendar)
            }
        }

        return nil
    }

    private static func monthDay(month: Int, day: Int, referenceDate: Date, calendar: Calendar) -> TodoDate? {
        let currentYear = calendar.component(.year, from: referenceDate)
        for year in [currentYear, currentYear + 1] {
            var components = DateComponents()
            components.calendar = calendar
            components.year = year
            components.month = month
            components.day = day

            guard let candidate = components.date else {
                continue
            }

            if candidate >= calendar.startOfDay(for: referenceDate) {
                return todoDate(from: candidate, calendar: calendar)
            }
        }

        return nil
    }

    private static func endOfMonth(referenceDate: Date, calendar: Calendar) -> TodoDate? {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let dayRange = calendar.range(of: .day, in: .month, for: startOfDay) else {
            return nil
        }

        let year = calendar.component(.year, from: startOfDay)
        let month = calendar.component(.month, from: startOfDay)
        return TodoDate(year: year, month: month, day: dayRange.count)
    }

    private static func todoDate(from date: Date, calendar: Calendar) -> TodoDate? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        return TodoDate(year: year, month: month, day: day)
    }

    private struct RegexMatch {
        let range: Range<String.Index>
        let captures: [String]
    }

    private static func firstRegexMatch(in rawText: String, pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        guard let match = regex.firstMatch(in: rawText, options: [], range: nsRange),
              let range = Range(match.range, in: rawText)
        else {
            return nil
        }

        let captures = (1..<match.numberOfRanges).compactMap { index -> String? in
            guard let captureRange = Range(match.range(at: index), in: rawText) else {
                return nil
            }

            return String(rawText[captureRange])
        }

        return RegexMatch(range: range, captures: captures)
    }
}
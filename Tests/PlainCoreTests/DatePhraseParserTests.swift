import Foundation
import Testing
@testable import PlainCore

@Test
func previewTransformsTomorrowIntoDueDate() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))

    let preview = try #require(
        DatePhraseParser.preview(
            for: "Review PR tomorrow @work +shipping",
            referenceDate: referenceDate,
            calendar: calendar
        )
    )

    #expect(preview.sourcePhrase.lowercased() == "tomorrow")
    #expect(preview.dueDate == TodoDate(year: 2026, month: 5, day: 27))
    #expect(preview.transformedText == "Review PR due:2026-05-27 @work +shipping")
}

@Test
func previewTransformsWeekdayPhraseIntoNextOccurrence() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))

    let preview = try #require(
        DatePhraseParser.preview(
            for: "(B) Call accountant friday @phone +taxes",
            referenceDate: referenceDate,
            calendar: calendar
        )
    )

    #expect(preview.dueDate == TodoDate(year: 2026, month: 5, day: 29))
    #expect(preview.transformedText == "(B) Call accountant due:2026-05-29 @phone +taxes")
}

@Test
func previewTransformsEndOfMonthPhrase() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 10)))

    let preview = try #require(
        DatePhraseParser.preview(
            for: "File taxes end of month +finance",
            referenceDate: referenceDate,
            calendar: calendar
        )
    )

    #expect(preview.dueDate == TodoDate(year: 2026, month: 2, day: 28))
    #expect(preview.transformedText == "File taxes due:2026-02-28 +finance")
}

@Test
func previewTransformsMonthDayIntoNearestFutureDate() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 26)))

    let preview = try #require(
        DatePhraseParser.preview(
            for: "Ship release june 5 +plain",
            referenceDate: referenceDate,
            calendar: calendar
        )
    )

    #expect(preview.dueDate == TodoDate(year: 2026, month: 6, day: 5))
    #expect(preview.transformedText == "Ship release due:2026-06-05 +plain")
}

@Test
func previewDoesNotTransformWhenDueMetadataAlreadyExists() throws {
    let preview = DatePhraseParser.preview(for: "Review PR due:2026-05-29 friday @work")
    #expect(preview == nil)
}
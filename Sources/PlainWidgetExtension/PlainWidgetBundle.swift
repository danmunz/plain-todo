import AppIntents
import PlainCore
import SwiftUI
import WidgetKit

// MARK: - Intent

struct PlainWidgetFilterIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Filter"
    static let description = IntentDescription("Choose which tasks to show.")

    @Parameter(title: "Filter", default: .todayAndOverdue)
    var filter: WidgetFilter
}

enum WidgetFilter: String, AppEnum {
    case todayAndOverdue
    case inbox
    case today
    case overdue

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Filter"
    static let caseDisplayRepresentations: [WidgetFilter: DisplayRepresentation] = [
        .todayAndOverdue: "Today + Overdue",
        .inbox: "Inbox",
        .today: "Today",
        .overdue: "Overdue",
    ]
}

// MARK: - Entry

private struct PlainWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PlainWidgetSnapshot
    let filter: WidgetFilter
}

// MARK: - Provider

private struct PlainWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlainWidgetEntry {
        PlainWidgetEntry(date: Date(), snapshot: .placeholder, filter: .todayAndOverdue)
    }

    func snapshot(for configuration: PlainWidgetFilterIntent, in context: Context) async -> PlainWidgetEntry {
        let snapshot = PlainWidgetSnapshotStore.load() ?? .placeholder
        return PlainWidgetEntry(date: Date(), snapshot: snapshot, filter: configuration.filter)
    }

    func timeline(for configuration: PlainWidgetFilterIntent, in context: Context) async -> Timeline<PlainWidgetEntry> {
        let snapshot = PlainWidgetSnapshotStore.load() ?? .placeholder
        let entry = PlainWidgetEntry(date: Date(), snapshot: snapshot, filter: configuration.filter)

        // Refresh every 15 minutes, or at midnight for date rollover
        let calendar = Calendar.current
        let now = Date()
        let nextQuarter = calendar.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        var midnightComponents = calendar.dateComponents([.year, .month, .day], from: now)
        midnightComponents.day! += 1
        let midnight = calendar.date(from: midnightComponents) ?? nextQuarter
        let nextRefresh = min(nextQuarter, midnight)

        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

// MARK: - View

private struct PlainWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlainWidgetEntry

    private var filteredCount: Int {
        switch entry.filter {
        case .todayAndOverdue:
            return entry.snapshot.todayCount + entry.snapshot.overdueCount
        case .inbox:
            return entry.snapshot.inboxCount
        case .today:
            return entry.snapshot.todayCount
        case .overdue:
            return entry.snapshot.overdueCount
        }
    }

    private var filterTitle: String {
        switch entry.filter {
        case .todayAndOverdue: return "Today + Overdue"
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .overdue: return "Overdue"
        }
    }

    private var deepLinkURL: String {
        switch entry.filter {
        case .todayAndOverdue: return "plain://today"
        case .inbox: return "plain://inbox"
        case .today: return "plain://today"
        case .overdue: return "plain://overdue"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(filterTitle)
                    .font(.headline)
                Spacer()
                Text("\(filteredCount)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(entry.snapshot.sourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if family == .systemMedium {
                HStack(spacing: 10) {
                    countChip(label: "Inbox", value: entry.snapshot.inboxCount)
                    countChip(label: "Today", value: entry.snapshot.todayCount)
                    countChip(label: "Overdue", value: entry.snapshot.overdueCount)
                    countChip(label: "Done", value: entry.snapshot.doneCount)
                }
            }

            if entry.snapshot.previewTasks.isEmpty {
                Text("No tasks")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.snapshot.previewTasks.prefix(family == .systemMedium ? 4 : 3), id: \.self) { task in
                    Text("• \(task)")
                        .font(.footnote)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if family == .systemMedium {
                Text(entry.snapshot.generatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private func countChip(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct PlainOverviewWidget: Widget {
    let kind = PlainWidgetConfig.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PlainWidgetFilterIntent.self, provider: PlainWidgetProvider()) { entry in
            PlainWidgetEntryView(entry: entry)
                .widgetURL(URL(string: entry.snapshot.deepLinkURL))
        }
        .configurationDisplayName("Plain Tasks")
        .description("See task counts and preview for a chosen filter.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PlainWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlainOverviewWidget()
    }
}

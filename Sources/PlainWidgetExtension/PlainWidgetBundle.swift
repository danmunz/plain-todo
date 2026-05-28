import PlainCore
import SwiftUI
import WidgetKit

private struct PlainWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PlainWidgetSnapshot
}

private struct PlainWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlainWidgetEntry {
        PlainWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlainWidgetEntry) -> Void) {
        let snapshot = PlainWidgetSnapshotStore.load() ?? .placeholder
        completion(PlainWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlainWidgetEntry>) -> Void) {
        let snapshot = PlainWidgetSnapshotStore.load() ?? .placeholder
        let entry = PlainWidgetEntry(date: Date(), snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct PlainWidgetEntryView: View {
    let entry: PlainWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.snapshot.selectionTitle)
                .font(.headline)
            Text(entry.snapshot.sourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 10) {
                countChip(label: "Inbox", value: entry.snapshot.inboxCount)
                countChip(label: "Today", value: entry.snapshot.todayCount)
                countChip(label: "Overdue", value: entry.snapshot.overdueCount)
            }

            if entry.snapshot.previewTasks.isEmpty {
                Text("No tasks to preview")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.snapshot.previewTasks.prefix(3), id: \.self) { task in
                    Text("• \(task)")
                        .font(.footnote)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
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
        StaticConfiguration(kind: kind, provider: PlainWidgetProvider()) { entry in
            PlainWidgetEntryView(entry: entry)
                .widgetURL(URL(string: entry.snapshot.deepLinkURL))
        }
        .configurationDisplayName("Plain Overview")
        .description("See Inbox, Today, and Overdue counts at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PlainWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlainOverviewWidget()
    }
}

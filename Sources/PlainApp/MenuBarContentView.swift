import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Plain")
                    .font(PlainType.sidebarLabel)
                Text(model.sourceDescription)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.TextToken.muted)
            }

            Divider()

            Button {
                select(.inbox)
            } label: {
                menuRow(title: "Inbox", count: model.inboxCount)
            }
            .accessibilityLabel("Inbox, \(model.inboxCount) tasks")

            Button {
                select(.today)
            } label: {
                menuRow(title: "Today", count: model.todayCount)
            }
            .accessibilityLabel("Today, \(model.todayCount) tasks")

            Button {
                select(.overdue)
            } label: {
                menuRow(title: "Overdue", count: model.overdueCount)
            }
            .accessibilityLabel("Overdue, \(model.overdueCount) tasks")

            Divider()

            Button("Quick Add") {
                quickAddController.showPanel()
            }
            .accessibilityLabel("Quick Add Task")

            Button("Open Plain") {
                quickAddController.revealMainWindow()
            }
            .accessibilityLabel("Open Main Window")
        }
        .padding(12)
        .frame(width: 260)
        .onAppear {
            model.loadInitialSnapshotIfNeeded()
        }
    }

    private func select(_ selection: SidebarSelection) {
        model.selection = selection
        quickAddController.revealMainWindow()
    }

    private func menuRow(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(PlainTokens.TextToken.muted)
        }
        .contentShape(Rectangle())
    }
}
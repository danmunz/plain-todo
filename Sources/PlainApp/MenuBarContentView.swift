import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plain")
                    .font(.headline)
                Text(model.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                select(.inbox)
            } label: {
                menuRow(title: "Inbox", count: model.inboxCount)
            }

            Button {
                select(.today)
            } label: {
                menuRow(title: "Today", count: model.todayCount)
            }

            Button {
                select(.overdue)
            } label: {
                menuRow(title: "Overdue", count: model.overdueCount)
            }

            Divider()

            Button("Quick Add") {
                quickAddController.showPanel()
            }

            Button("Open Plain") {
                quickAddController.revealMainWindow()
            }
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
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
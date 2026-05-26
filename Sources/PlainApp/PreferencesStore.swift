import SwiftUI

enum ArchiveBehavior: String, CaseIterable, Identifiable {
    case manual
    case automatic

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .manual:
            return "Archive manually"
        case .automatic:
            return "Archive on completion"
        }
    }
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var archiveBehavior: ArchiveBehavior {
        didSet {
            userDefaults.set(archiveBehavior.rawValue, forKey: archiveBehaviorKey)
        }
    }

    @Published var automaticallyAddCreationDate: Bool {
        didSet {
            userDefaults.set(automaticallyAddCreationDate, forKey: automaticallyAddCreationDateKey)
        }
    }

    @Published var showCompletedTasks: Bool {
        didSet {
            userDefaults.set(showCompletedTasks, forKey: showCompletedTasksKey)
        }
    }

    @Published var showMenuBarItem: Bool {
        didSet {
            userDefaults.set(showMenuBarItem, forKey: showMenuBarItemKey)
        }
    }

    private let userDefaults: UserDefaults
    private let archiveBehaviorKey = "PlainArchiveBehavior"
    private let automaticallyAddCreationDateKey = "PlainAutomaticallyAddCreationDate"
    private let showCompletedTasksKey = "PlainShowCompletedTasks"
    private let showMenuBarItemKey = "PlainShowMenuBarItem"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: archiveBehaviorKey),
           let archiveBehavior = ArchiveBehavior(rawValue: rawValue)
        {
            self.archiveBehavior = archiveBehavior
        } else {
            self.archiveBehavior = .manual
        }

        if userDefaults.object(forKey: automaticallyAddCreationDateKey) == nil {
            self.automaticallyAddCreationDate = true
        } else {
            self.automaticallyAddCreationDate = userDefaults.bool(forKey: automaticallyAddCreationDateKey)
        }

        if userDefaults.object(forKey: showCompletedTasksKey) == nil {
            self.showCompletedTasks = true
        } else {
            self.showCompletedTasks = userDefaults.bool(forKey: showCompletedTasksKey)
        }

        if userDefaults.object(forKey: showMenuBarItemKey) == nil {
            self.showMenuBarItem = false
        } else {
            self.showMenuBarItem = userDefaults.bool(forKey: showMenuBarItemKey)
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            Picker("Archive behavior", selection: $preferences.archiveBehavior) {
                ForEach(ArchiveBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .pickerStyle(.radioGroup)

            Toggle("Automatically add creation date to new tasks", isOn: $preferences.automaticallyAddCreationDate)
            Toggle("Show completed tasks", isOn: $preferences.showCompletedTasks)
            Toggle("Show menu bar item", isOn: $preferences.showMenuBarItem)
        }
        .padding(20)
        .frame(minWidth: 380)
    }
}
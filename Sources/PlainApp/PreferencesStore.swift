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

    private let userDefaults: UserDefaults
    private let archiveBehaviorKey = "PlainArchiveBehavior"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: archiveBehaviorKey),
           let archiveBehavior = ArchiveBehavior(rawValue: rawValue)
        {
            self.archiveBehavior = archiveBehavior
        } else {
            self.archiveBehavior = .manual
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
        }
        .padding(20)
        .frame(minWidth: 380)
    }
}
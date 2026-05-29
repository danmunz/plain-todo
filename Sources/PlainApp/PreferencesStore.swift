import AppKit
import SwiftUI

private struct PlainFontSizeKey: EnvironmentKey {
    static let defaultValue: Double = 13
}

extension EnvironmentValues {
    var plainFontSize: Double {
        get { self[PlainFontSizeKey.self] }
        set { self[PlainFontSizeKey.self] = newValue }
    }
}

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

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Follow system"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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

    @Published var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: themeKey)
        }
    }

    @Published var fontSize: Double {
        didSet {
            userDefaults.set(fontSize, forKey: fontSizeKey)
        }
    }

    @Published var defaultPriority: String? {
        didSet {
            userDefaults.set(defaultPriority, forKey: defaultPriorityKey)
        }
    }

    @Published var createBackup: Bool {
        didSet {
            userDefaults.set(createBackup, forKey: createBackupKey)
        }
    }

    @Published var debugLogging: Bool {
        didSet {
            userDefaults.set(debugLogging, forKey: debugLoggingKey)
        }
    }

    private let userDefaults: UserDefaults
    private let archiveBehaviorKey = "PlainArchiveBehavior"
    private let automaticallyAddCreationDateKey = "PlainAutomaticallyAddCreationDate"
    private let showCompletedTasksKey = "PlainShowCompletedTasks"
    private let showMenuBarItemKey = "PlainShowMenuBarItem"
    private let themeKey = "PlainTheme"
    private let fontSizeKey = "PlainFontSize"
    private let defaultPriorityKey = "PlainDefaultPriority"
    private let createBackupKey = "PlainCreateBackup"
    private let debugLoggingKey = "PlainDebugLogging"

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

        if let rawValue = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: rawValue)
        {
            self.theme = theme
        } else {
            self.theme = .system
        }

        if userDefaults.object(forKey: fontSizeKey) == nil {
            self.fontSize = 13
        } else {
            self.fontSize = userDefaults.double(forKey: fontSizeKey)
        }

        self.defaultPriority = userDefaults.string(forKey: defaultPriorityKey)

        self.createBackup = userDefaults.bool(forKey: createBackupKey)
        self.debugLogging = userDefaults.bool(forKey: debugLoggingKey)
    }
}

struct PreferencesView: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        TabView {
            GeneralPreferencesTab(preferences: preferences)
                .tabItem { Label("General", systemImage: "gear") }
            AppearancePreferencesTab(preferences: preferences)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ShortcutsPreferencesTab(preferences: preferences)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AdvancedPreferencesTab(preferences: preferences)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 320)
    }
}

private struct GeneralPreferencesTab: View {
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

            Picker("Default priority for new tasks", selection: Binding(
                get: { preferences.defaultPriority ?? "none" },
                set: { preferences.defaultPriority = $0 == "none" ? nil : $0 }
            )) {
                Text("None").tag("none")
                Text("A").tag("A")
                Text("B").tag("B")
                Text("C").tag("C")
            }
        }
        .padding(20)
    }
}

private struct AppearancePreferencesTab: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            Picker("Theme", selection: $preferences.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.radioGroup)

            VStack(alignment: .leading, spacing: 4) {
                Text("Font size: \(Int(preferences.fontSize))pt")
                Slider(value: $preferences.fontSize, in: 11...18, step: 1)
            }

            Toggle("Show completed tasks in list", isOn: $preferences.showCompletedTasks)
        }
        .padding(20)
    }
}

private struct ShortcutsPreferencesTab: View {
    @ObservedObject var preferences: PreferencesStore

    private let shortcuts: [(String, String)] = [
        ("New task", "⌘N"),
        ("Toggle completion", "Space"),
        ("Edit task", "Return"),
        ("Delete task", "⌫"),
        ("Search", "⌘F"),
        ("Select all", "⌘A"),
        ("Move task up", "⌥↑"),
        ("Move task down", "⌥↓"),
        ("Extend selection", "⇧↑ / ⇧↓"),
        ("Navigate up/down", "↑↓ or J/K"),
        ("Set priority A/B/C", "⌘1 / ⌘2 / ⌘3"),
        ("Clear priority", "⌘0"),
        ("Cycle sort mode", "⌘⇧S"),
        ("Archive completed", "⌘⇧A"),
        ("Scratch pad", "⌘E"),
        ("Quick add (global)", "⌃⌥T"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Show menu bar icon", isOn: $preferences.showMenuBarItem)

            Divider()

            Text("Keyboard Shortcuts")
                .font(.headline)

            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    ForEach(shortcuts, id: \.0) { shortcut in
                        GridRow {
                            Text(shortcut.0)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(shortcut.1)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
    }
}

private struct AdvancedPreferencesTab: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            LabeledContent("File encoding") {
                Text("UTF-8")
                    .foregroundStyle(.secondary)
            }

            Toggle("Create .bak backup before writing", isOn: $preferences.createBackup)

            Toggle("Enable debug logging", isOn: $preferences.debugLogging)
        }
        .padding(20)
    }
}
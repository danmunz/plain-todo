import SwiftUI
import AppKit

struct PlainAppScenes: Scene {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController
    let isRunningTests: Bool
    let updaterController: UpdaterController

    var body: some Scene {
        PlainMainWindowScene(preferences: preferences, model: model, quickAddController: quickAddController, updaterController: updaterController)
        PlainSettingsScene(preferences: preferences)
        PlainMenuBarScene(preferences: preferences, model: model, quickAddController: quickAddController, isRunningTests: isRunningTests)
    }
}

private struct PlainMainWindowScene: Scene {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController
    let updaterController: UpdaterController

    var body: some Scene {
        WindowGroup(id: "main") {
            PlainShellView(model: model)
                .background(MainWindowRegistrationView(controller: quickAddController))
                .onOpenURL { url in
                    model.openDeepLink(url)
                }
                .preferredColorScheme(preferences.theme.colorScheme)
                .environment(\.plainFontSize, preferences.fontSize)
                .tint(PlainTokens.accent)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .plainOpenFile, object: nil)
                }
                .keyboardShortcut("o")
            }

            CommandGroup(after: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .plainFocusInputBar, object: nil)
                }
                .keyboardShortcut("n")
            }

            CommandGroup(replacing: .help) {
                Button("Plain Help") {
                    if let url = URL(string: "https://github.com/todotxt/todo.txt") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .plainToggleSidebar, object: nil)
                }
                .keyboardShortcut("\\", modifiers: [.command])

                Divider()

                Button("Cycle Sort Mode") {
                    model.cycleSortMode()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Plain") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "Plain reads your todo.txt.\nThat's it, really.",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor,
                            ]
                        ),
                    ])
                }
                Divider()
                CheckForUpdatesView(updaterController: updaterController)
            }
        }
    }
}

private struct PlainMenuBarScene: Scene {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController
    let isRunningTests: Bool

    var body: some Scene {
        MenuBarExtra(
            "Plain",
            systemImage: "checklist",
            isInserted: Binding(
                get: {
                    if isRunningTests {
                        return false
                    }
                    return preferences.showMenuBarItem
                },
                set: { newValue in
                    guard !isRunningTests, preferences.showMenuBarItem != newValue else {
                        return
                    }
                    preferences.showMenuBarItem = newValue
                }
            )
        ) {
            MenuBarContentView(model: model, quickAddController: quickAddController)
        }
    }
}

private struct PlainSettingsScene: Scene {
    @ObservedObject var preferences: PreferencesStore

    var body: some Scene {
        Settings {
            PreferencesView(preferences: preferences)
        }
    }
}
import SwiftUI

struct PlainAppScenes: Scene {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController
    let isRunningTests: Bool

    var body: some Scene {
        PlainMainWindowScene(preferences: preferences, model: model, quickAddController: quickAddController)
        PlainSettingsScene(preferences: preferences)
    }
}

private struct PlainMainWindowScene: Scene {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var model: PlainShellModel
    @ObservedObject var quickAddController: QuickAddPanelController

    var body: some Scene {
        WindowGroup(id: "main") {
            PlainShellView(model: model)
                .background(MainWindowRegistrationView(controller: quickAddController))
                .onOpenURL { url in
                    model.openDeepLink(url)
                }
                .preferredColorScheme(preferences.theme.colorScheme)
                .environment(\.plainFontSize, preferences.fontSize)
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
                    guard !isRunningTests else {
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
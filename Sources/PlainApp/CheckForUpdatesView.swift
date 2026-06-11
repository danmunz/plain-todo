import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    private let updaterController: UpdaterController

    init(updaterController: UpdaterController) {
        self.updaterController = updaterController
    }

    var body: some View {
        Button("Check for Updates...") {
            updaterController.startIfNeeded()
            updaterController.updater.checkForUpdates()
        }
    }
}

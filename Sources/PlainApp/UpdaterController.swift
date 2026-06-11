import Foundation
import Sparkle

@MainActor
final class UpdaterController {
    private let controller: SPUStandardUpdaterController
    var updater: SPUUpdater { controller.updater }

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func startIfNeeded() {
        guard !updater.sessionInProgress else { return }
        do {
            try updater.start()
        } catch {
            // Updater start can fail on unsigned dev builds — not fatal.
        }
    }
}

import Foundation
import TKLogging

final class PerpsSectionTooltipController {
    private let repository: PerpsSectionTooltipRepository
    private let appSettings: AppSettings

    init(repository: PerpsSectionTooltipRepository, appSettings: AppSettings) {
        self.repository = repository
        self.appSettings = appSettings
    }
}

extension PerpsSectionTooltipController: TooltipController {
    var canShowTooltip: Bool {
        guard !appSettings.isPerpsStoryAccepted else {
            Log.tooltips.i("perps section tooltip is not needed, perps has been opened")
            return false
        }
        return !repository.hasBeenShown
    }

    func didShowTooltip() {
        repository.hasBeenShown = true
        Log.tooltips.i("perps section tooltip has been shown")
    }

    func didPerformTargetAction() {
        repository.hasBeenShown = true
        Log.tooltips.i("perps section tooltip target action has performed")
    }

    func didDismiss() {
        Log.tooltips.i("perps section tooltip has been dismissed")
    }
}

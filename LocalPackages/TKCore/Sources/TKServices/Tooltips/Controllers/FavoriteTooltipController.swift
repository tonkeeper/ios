import Foundation
import TKLogging

final class FavoriteTooltipController {
    private let favoriteTooltipRepository: FavoriteTooltipRepository

    init(favoriteTooltipRepository: FavoriteTooltipRepository) {
        self.favoriteTooltipRepository = favoriteTooltipRepository
    }
}

extension FavoriteTooltipController: TooltipController {
    var canShowTooltip: Bool {
        !favoriteTooltipRepository.hasBeenShown
    }

    func didShowTooltip() {
        favoriteTooltipRepository.hasBeenShown = true
        Log.tooltips.i("favorite tooltip has been shown")
    }

    func didPerformTargetAction() {
        favoriteTooltipRepository.hasBeenShown = true
        Log.tooltips.i("favorite tooltip's target action has performed")
    }

    func didDismiss() {
        Log.tooltips.i("favorite tooltip has been dismissed")
    }
}

import Foundation
import TKLogging

final class EarnSectionTooltipController {
    private let repository: EarnSectionTooltipRepository
    private let calendar: Calendar

    init(
        repository: EarnSectionTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.calendar = calendar
    }
}

extension EarnSectionTooltipController: TooltipController {
    var canShowTooltip: Bool {
        if let lastShownDate = repository.lastShownDate,
           calendar.isDateInToday(lastShownDate)
        {
            Log.tooltips.i("earn section tooltip already shown today")
            return false
        }
        guard repository.shownCount < Constants.maxTotalShows else {
            Log.tooltips.i("earn section tooltip reached max shows")
            return false
        }
        return true
    }

    func didShowTooltip() {
        repository.shownCount += 1
        repository.lastShownDate = Date()
        Log.tooltips.i("earn section tooltip has been shown, shown count: \(repository.shownCount) of \(Constants.maxTotalShows)")
    }

    func didPerformTargetAction() {
        Log.tooltips.i("earn section tooltip target action has performed")
        didDismiss()
    }

    func didDismiss() {
        Log.tooltips.i("earn section tooltip has been dismissed")
    }
}

private extension EarnSectionTooltipController {
    enum Constants {
        static let maxTotalShows = 3
    }
}

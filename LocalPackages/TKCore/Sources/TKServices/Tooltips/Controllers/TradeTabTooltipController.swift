import Foundation
import TKLogging

final class TradeTabTooltipController {
    private let calendar: Calendar
    private let commonTooltipsRepository: TooltipDataRepository
    private let tradeTabTooltipRepository: TradeTabTooltipRepository

    private var hasBeenShownInSession = false

    init(
        commonTooltipsRepository: TooltipDataRepository,
        tradeTabTooltipRepository: TradeTabTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.commonTooltipsRepository = commonTooltipsRepository
        self.tradeTabTooltipRepository = tradeTabTooltipRepository
    }
}

extension TradeTabTooltipController: TooltipController {
    var canShowTooltip: Bool {
        guard isExistingUser else {
            Log.tooltips.i("trade tab tooltip should not be shown for new users")
            shownCount = Constants.maxTotalShows
            return false
        }
        guard !isTargetActionPerformed else {
            return false
        }
        guard shownCount < Constants.maxTotalShows else {
            return false
        }
        guard !hasBeenShownInSession else {
            return false
        }
        return true
    }

    func didShowTooltip() {
        hasBeenShownInSession = true
        shownCount += 1
        Log.tooltips.i("trade tab tooltip has been shown, shown count: \(shownCount) of \(Constants.maxTotalShows)")
    }

    func didPerformTargetAction() {
        Log.tooltips.i("trade tab tooltip's target action has performed")
        isTargetActionPerformed = true
        didDismiss()
    }

    func didDismiss() {
        Log.tooltips.i("trade tab tooltip has been dismissed")
    }
}

private extension TradeTabTooltipController {
    private enum Constants {
        static let maxTotalShows = 2
    }

    var isExistingUser: Bool {
        guard let firstLaunchDate = commonTooltipsRepository.firstLaunchDate else { return false }
        return !calendar.isDateInToday(firstLaunchDate)
    }

    var shownCount: Int {
        get {
            tradeTabTooltipRepository.shownCount
        }
        set {
            tradeTabTooltipRepository.shownCount = newValue
        }
    }

    var isTargetActionPerformed: Bool {
        get {
            tradeTabTooltipRepository.isTargetActionPerformed
        }
        set {
            tradeTabTooltipRepository.isTargetActionPerformed = newValue
        }
    }
}

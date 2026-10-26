import Foundation
import TKLogging

final class NewHistoryEntryPointTooltipController {
    private let calendar: Calendar
    private let commonTooltipsRepository: TooltipDataRepository
    private let newHistoryEntryPointTooltipRepository: NewHistoryEntryPointTooltipRepository

    private var hasBeenShownInSession = false

    init(
        commonTooltipsRepository: TooltipDataRepository,
        newHistoryEntryPointTooltipRepository: NewHistoryEntryPointTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.commonTooltipsRepository = commonTooltipsRepository
        self.newHistoryEntryPointTooltipRepository = newHistoryEntryPointTooltipRepository
    }
}

extension NewHistoryEntryPointTooltipController: TooltipController {
    var canShowTooltip: Bool {
        guard isExistingUser else {
            Log.tooltips.i("new history entry point tooltip should not be shown for new users")
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
        Log.tooltips.i("new history entry point tooltip has been shown, shown count: \(shownCount) of \(Constants.maxTotalShows)")
    }

    func didPerformTargetAction() {
        Log.tooltips.i("new history entry point tooltip's target action has performed")
        isTargetActionPerformed = true
        didDismiss()
    }

    func didDismiss() {
        Log.tooltips.i("new history entry point tooltip has been dismissed")
    }
}

private extension NewHistoryEntryPointTooltipController {
    private enum Constants {
        static let maxTotalShows = 2
    }

    var isExistingUser: Bool {
        guard let firstLaunchDate = commonTooltipsRepository.firstLaunchDate else { return false }
        return !calendar.isDateInToday(firstLaunchDate)
    }

    var shownCount: Int {
        get {
            newHistoryEntryPointTooltipRepository.shownCount
        }
        set {
            newHistoryEntryPointTooltipRepository.shownCount = newValue
        }
    }

    var isTargetActionPerformed: Bool {
        get {
            newHistoryEntryPointTooltipRepository.isTargetActionPerformed
        }
        set {
            newHistoryEntryPointTooltipRepository.isTargetActionPerformed = newValue
        }
    }
}

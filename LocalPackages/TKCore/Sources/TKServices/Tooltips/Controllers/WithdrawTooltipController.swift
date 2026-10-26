import Foundation
import TKLogging

final class WithdrawTooltipController {
    private let calendar: Calendar
    private let commonTooltipsRepository: TooltipDataRepository
    private let withdrawTooltipRepository: WithdrawButtonTooltipRepository

    private var hasPresentedInSession = false

    init(
        commonTooltipsRepository: TooltipDataRepository,
        withdrawTooltipRepository: WithdrawButtonTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.commonTooltipsRepository = commonTooltipsRepository
        self.withdrawTooltipRepository = withdrawTooltipRepository
        self.calendar = calendar
    }
}

extension WithdrawTooltipController: TooltipController {
    var canShowTooltip: Bool {
        guard isExistingUser else {
            Log.tooltips.i("withdraw tooltip should not be shown for new users")
            isTargetActionPerformed = true
            return false
        }
        guard !isTargetActionPerformed else {
            return false
        }
        guard shownCount < Constants.maxTotalShows else {
            return false
        }
        guard !hasPresentedInSession else {
            return false
        }
        return true
    }

    func didShowTooltip() {
        hasPresentedInSession = true
        shownCount += 1
        Log.tooltips.i("withdraw tooltip has been shown, shown count: \(shownCount) of \(Constants.maxTotalShows)")
    }

    func didPerformTargetAction() {
        Log.tooltips.i("withdraw tooltip's target action has performed")
        isTargetActionPerformed = true
        didDismiss()
    }

    func didDismiss() {
        Log.tooltips.i("withdraw tooltip has been dismissed")
    }
}

extension WithdrawTooltipController {
    private enum Constants {
        static let maxTotalShows = 2
    }

    private var isExistingUser: Bool {
        guard let firstLaunchDate = commonTooltipsRepository.firstLaunchDate else { return false }
        return !calendar.isDateInToday(firstLaunchDate)
    }

    private var shownCount: Int {
        get {
            withdrawTooltipRepository.shownCount
        }
        set {
            withdrawTooltipRepository.shownCount = newValue
        }
    }

    private var isTargetActionPerformed: Bool {
        get {
            withdrawTooltipRepository.isTargetActionPerformed
        }
        set {
            withdrawTooltipRepository.isTargetActionPerformed = newValue
        }
    }
}

import Foundation
import KeeperCore
import TKFeatureFlags

final class WalletBalanceWithdrawTooltipServiceImplementation: WalletBalanceWithdrawTooltipService {
    private let configuration: Configuration
    private let calendar: Calendar
    private let commonToolipsRepository: TooltipDataRepository
    private let withdrawTooltipRepository: WithdrawButtonTooltipRepository

    private var hasPresentedInSession = false
    private var isDismissedInSession = false
    private var isTooltipVisible = false

    init(
        configuration: Configuration,
        commonToolipsRepository: TooltipDataRepository,
        withdrawTooltipRepository: WithdrawButtonTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.commonToolipsRepository = commonToolipsRepository
        self.withdrawTooltipRepository = withdrawTooltipRepository
        self.calendar = calendar
    }

    func shouldShowTooltip() -> Bool {
        guard configuration.featureEnabled(.newRampFlow) else {
            return false
        }
        guard isExistingUser else {
            markInstructionUnderstood()
            return false
        }
        guard !isInstructionUnderstood else {
            return false
        }
        if isTooltipVisible {
            return true
        }
        guard shownCount < Constants.maxTotalShows else {
            return false
        }
        guard !hasPresentedInSession, !isDismissedInSession else {
            return false
        }
        hasPresentedInSession = true
        isTooltipVisible = true
        shownCount += 1
        return true
    }

    func dismissTooltip() {
        isTooltipVisible = false
        isDismissedInSession = true
    }

    func markInstructionUnderstood() {
        isInstructionUnderstood = true
        dismissTooltip()
    }

    private var isExistingUser: Bool {
        guard let firstLaunchDate = commonToolipsRepository.firstLaunchDate else { return false }
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

    private var isInstructionUnderstood: Bool {
        get {
            withdrawTooltipRepository.isInstructionUnderstood
        }
        set {
            withdrawTooltipRepository.isInstructionUnderstood = newValue
        }
    }
}

private enum Constants {
    static let maxTotalShows = 2
}

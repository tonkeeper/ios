import Foundation
import TKLogging

final class AddMultichainWalletTooltipController {
    private let calendar: Calendar
    private let placement: AddMultichainWalletTooltipRepository.Placement
    private let repository: AddMultichainWalletTooltipRepository

    init(
        placement: AddMultichainWalletTooltipRepository.Placement,
        repository: AddMultichainWalletTooltipRepository,
        calendar: Calendar = .current
    ) {
        self.placement = placement
        self.repository = repository
        self.calendar = calendar
    }
}

extension AddMultichainWalletTooltipController: TooltipController {
    var canShowTooltip: Bool {
        if let placementLastShownDate = repository.lastShownDate(for: placement),
           calendar.isDateInToday(placementLastShownDate)
        {
            Log.tooltips.i("add multichain wallet tooltip (\(placement.rawValue)) already shown today")
            return false
        }

        if let lastShownDate = repository.lastShownDate,
           calendar.isDateInToday(lastShownDate)
        {
            // Another placement already counted today — still allow this placement.
            return true
        }

        guard repository.shownCount < Constants.maxTotalShows else {
            Log.tooltips.i("add multichain wallet tooltip reached max shows")
            return false
        }
        return true
    }

    func didShowTooltip() {
        let today = Date()
        if repository.lastShownDate.map({ !calendar.isDateInToday($0) }) ?? true {
            repository.shownCount += 1
            repository.lastShownDate = today
        }
        repository.setLastShownDate(today, for: placement)
        Log.tooltips.i(
            "add multichain wallet tooltip (\(placement.rawValue)) has been shown, shown count: \(repository.shownCount) of \(Constants.maxTotalShows)"
        )
    }

    func didPerformTargetAction() {
        Log.tooltips.i("add multichain wallet tooltip (\(placement.rawValue)) target action has performed")
        didDismiss()
    }

    func didDismiss() {
        Log.tooltips.i("add multichain wallet tooltip (\(placement.rawValue)) has been dismissed")
    }
}

private extension AddMultichainWalletTooltipController {
    enum Constants {
        static let maxTotalShows = 3
    }
}

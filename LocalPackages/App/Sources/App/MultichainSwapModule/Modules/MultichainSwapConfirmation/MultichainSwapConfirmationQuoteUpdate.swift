import Foundation

/// One refresh countdown of the swap screen's quote, which the confirmation shows as well.
struct MultichainSwapQuoteRefreshCycle: Equatable {
    let startDate: Date
    let duration: TimeInterval
}

/// The swap screen's quote as the confirmation follows it: the screen is the only one asking for
/// quotes on a timer, so the two never show different quotes or restart each other's countdown.
enum MultichainSwapConfirmationQuoteUpdate {
    case loading
    case ready(MultichainSwapConfirmationInput, MultichainSwapQuoteRefreshCycle)
    case failed(MultichainSwapConfirmationQuoteFailure)
}

/// Why the swap screen has no quote the confirmation can act on.
enum MultichainSwapConfirmationQuoteFailure: Equatable {
    case quote(MultichainSwapQuoteFailure)
    /// The quote is there, but its route spends more than the balance holds.
    case insufficientBalance
}

enum MultichainSwapConfirmationQuoteStatus: Equatable {
    case loading
    case ready(MultichainSwapQuoteRefreshCycle)
    case failed(String)
}

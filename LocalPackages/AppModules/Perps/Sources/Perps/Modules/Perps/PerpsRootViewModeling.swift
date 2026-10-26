import Foundation
import PerpsModels

@MainActor
public protocol PerpsRootViewModeling: ObservableObject {
    var accountState: PerpsRootAccountState { get }
    var marketsState: PerpsRootMarketsState { get }
    var sort: PerpsMarketsSort { get }
    /// A deposit on its way to the balance, then its arrival for a moment.
    var fundingToast: PerpsAssetPageTradeToast? { get }
    /// Rendered when the account has no portfolio yet, so the balance slot keeps
    /// its formatting instead of collapsing to a placeholder.
    var zeroBalanceText: String { get }

    var onBack: (() -> Void)? { get }
    var onLearnBasics: (() -> Void)? { get }
    var onSearch: (() -> Void)? { get }
    var onHistory: (() -> Void)? { get }
    var onDeposit: (() -> Void)? { get }
    var onWithdraw: (() -> Void)? { get }

    func onAppear()
    func onDisappear()
    /// Opens the history on the operation the funding toast is about.
    func openFundingToast()
    func setSort(_ sort: PerpsMarketsSort)
    func selectMarket(_ id: Int64)
    func rowAppeared(_ id: Int64)
    func rowDisappeared(_ id: Int64)
}

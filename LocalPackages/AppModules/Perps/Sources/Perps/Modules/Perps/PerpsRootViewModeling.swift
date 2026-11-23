import Foundation
import PerpsModels

@MainActor
public protocol PerpsRootViewModeling: ObservableObject {
    var accountState: PerpsRootAccountState { get }
    /// Placeholder rows for the open positions while they load; 0 shows no placeholder.
    var loadingPositionsCount: Int { get }
    var marketsState: PerpsRootMarketsState { get }
    var sort: PerpsMarketsSort { get }
    var depositStatus: PerpsDepositStatusViewModel? { get }
    var withdrawStatus: PerpsWithdrawStatusViewModel? { get }
    var isRegionRestricted: Bool { get }
    /// Rendered when the account has no portfolio yet, so the balance slot keeps
    /// its formatting instead of collapsing to a placeholder.
    var zeroBalanceText: String { get }

    var onBack: (() -> Void)? { get }
    var onLearnBasics: (() -> Void)? { get }
    var onSearch: (() -> Void)? { get }
    var onHistory: (() -> Void)? { get }
    var onDeposit: (() -> Void)? { get }
    var onWithdraw: (() -> Void)? { get }
    var onRegionRestrictionInfo: (() -> Void)? { get }

    func onWillAppear()
    func onAppear()
    func onDisappear()
    func setSort(_ sort: PerpsMarketsSort)
    func selectMarket(_ id: Int64)
    func rowAppeared(_ id: Int64)
    func rowDisappeared(_ id: Int64)
}

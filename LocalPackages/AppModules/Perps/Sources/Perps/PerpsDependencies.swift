import PerpsModels
import TKCoordinator
import UIKit

/// The object graph the perps flow reads from. Everything here is a port, so the feature
/// never names a live store, a service or a formatter.
public protocol PerpsDependencies {
    var marketsRepository: any PerpsMarketsSearching { get }
    var marketsStore: any PerpsMarketsStoring { get }
    var chartService: any PerpsChartProviding { get }
    var format: PerpsFormatting { get }
    func makeMarketDetailsStore() -> any PerpsMarketDetailsStoring
}

public enum PerpsAccountActivationResult {
    case activated
    case canceled
    case failed
}

public typealias PerpsAccountActivating = @MainActor (
    _ parentCoordinator: Coordinator,
    _ parentRouter: NavigationControllerRouter,
    _ onPasscodeEntered: @escaping @MainActor () -> Void
) async -> PerpsAccountActivationResult

public typealias PerpsSigningPasscodeProviding = @MainActor (
    _ parentCoordinator: Coordinator,
    _ parentRouter: ContainerViewControllerRouter<UIViewController>
) async -> String?

/// Runs for as long as the flow is on screen; the app side owns the app-state and
/// reachability signals that gate the recovery.
public typealias PerpsFundingRecovery = @MainActor () async -> Void

/// Wakes the recovery right after a deposit is recorded instead of on its next tick.
public typealias PerpsFundingRefresh = @MainActor () async -> Void

/// `nil` for a wallet that cannot deposit: no multichain id, or no Ethereum address.
public typealias PerpsDepositProviding = @MainActor () -> (any PerpsDepositing)?

/// `nil` while the wallet cannot withdraw — today always: the withdrawal itself is not built yet.
public typealias PerpsWithdrawProviding = @MainActor () -> (any PerpsWithdrawing)?

/// The perps history is the multichain activity list filtered to perps — one market's
/// events, or every market's for `nil` — which the app side owns. A position event is
/// handed back to the flow, which shows it the same way the asset page does. The first row
/// carrying one of `focusedTransactions` is opened as soon as it loads. `withdrawalOperationId`
/// keeps reloading the list for a while: a withdrawal just sent may not be listed yet.
/// `focusedFundingOperationId` follows the operation's hashes as funding recovery loads them.
public typealias PerpsHistoryProviding = @MainActor (
    _ marketId: Int64?,
    _ focusedTransactions: Set<String>,
    _ withdrawalOperationId: String?,
    _ focusedFundingOperationId: String?,
    _ onSelectEvent: @escaping (PerpsHistoryEvent) -> Void,
    _ onOpenTransaction: @escaping (URL, String?) -> Void
) -> UIViewController?

/// The per-wallet half of the graph: it changes when the active wallet does.
public struct PerpsWalletDependencies {
    public let accountStore: any PerpsAccountStoring
    public let tradingService: any PerpsTradingService
    public let activateAccount: PerpsAccountActivating
    public let signingPasscode: PerpsSigningPasscodeProviding
    public let recoverFunding: PerpsFundingRecovery
    public let refreshFunding: PerpsFundingRefresh
    public let makeDeposit: PerpsDepositProviding
    public let makeWithdraw: PerpsWithdrawProviding
    public let makeHistory: PerpsHistoryProviding

    public init(
        accountStore: any PerpsAccountStoring,
        tradingService: any PerpsTradingService,
        activateAccount: @escaping PerpsAccountActivating,
        signingPasscode: @escaping PerpsSigningPasscodeProviding,
        recoverFunding: @escaping PerpsFundingRecovery,
        refreshFunding: @escaping PerpsFundingRefresh,
        makeDeposit: @escaping PerpsDepositProviding,
        makeWithdraw: @escaping PerpsWithdrawProviding = { nil },
        makeHistory: @escaping PerpsHistoryProviding
    ) {
        self.accountStore = accountStore
        self.tradingService = tradingService
        self.activateAccount = activateAccount
        self.signingPasscode = signingPasscode
        self.recoverFunding = recoverFunding
        self.refreshFunding = refreshFunding
        self.makeDeposit = makeDeposit
        self.makeWithdraw = makeWithdraw
        self.makeHistory = makeHistory
    }
}

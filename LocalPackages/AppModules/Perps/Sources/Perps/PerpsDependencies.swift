import PerpsModels
import TKCoordinator
import UIKit

/// The object graph the perps flow reads from. Everything here is a port, so the feature
/// never names a live store, a service or a formatter.
public protocol PerpsDependencies {
    var marketsRepository: any PerpsMarketsSearching { get }
    var marketsStore: any PerpsMarketsStoring { get }
    var chartService: any PerpsChartProviding { get }
    var access: PerpsAccess { get }
    var format: PerpsFormatting { get }
    func reloadAccess() async -> PerpsAccess
    func observeAccess<Observer: AnyObject>(_ observer: Observer, onChange: @escaping @Sendable (Observer) -> Void)
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
/// `sheetPresenter` is where the app side shows what it asks over the flow, such as the fee picker.
public typealias PerpsDepositProviding = @MainActor (
    _ sheetPresenter: @escaping @MainActor () async -> UIViewController?
) -> (any PerpsDepositing)?

/// `nil` while the wallet cannot withdraw — today always: the withdrawal itself is not built yet.
public typealias PerpsWithdrawProviding = @MainActor () -> (any PerpsWithdrawing)?

/// The perps history is the multichain activity list filtered to perps — one market's
/// events, or every market's for `nil` — which the app side owns. A position event is
/// handed back to the flow, which shows it the same way the asset page does. The first row
/// carrying one of `focusedTransactions` is opened as soon as it loads. `focusedFundingOperationId`
/// follows the operation's hashes as funding recovery loads them and keeps reloading the list for
/// a while: an operation just sent may not be listed yet.
public typealias PerpsHistoryProviding = @MainActor (
    _ marketId: Int64?,
    _ focusedTransactions: Set<String>,
    _ focusedFundingOperationId: String?,
    _ onSelectEvent: @escaping (PerpsHistoryEvent) -> Void,
    _ onOpenTransaction: @escaping (URL, String?) -> Void
) -> UIViewController?

public enum PerpsDepositEntry {
    case home
    case openPosition
    case addToPosition
    case addMargin
}

public enum PerpsDepositStep {
    case amount
    case confirm
    /// The amount screen's own minimum quote found it before anything is shown.
    case background
}

public enum PerpsDepositFailure {
    case belowMinimum
    case insufficientBalance
    case insufficientNetworkFee
    case quoteExpired
    case quoteChanged
    case depositInProgress
    case addressBlocked
    case failed

    init?(_ message: PerpsDepositMessage) {
        switch message {
        case .belowMinimum: self = .belowMinimum
        case .insufficientBalance: self = .insufficientBalance
        case .insufficientNetworkFee: self = .insufficientNetworkFee
        case .quoteExpired: self = .quoteExpired
        case .quoteChanged: self = .quoteChanged
        case .accountCreationPending: self = .depositInProgress
        case .addressBlocked: self = .addressBlocked
        case .failed: self = .failed
        case .canceled, .regionRestricted: return nil
        }
    }
}

public enum PerpsAnalyticsEvent {
    case depositStarted(eligibleAssetsCount: Int?)
    case depositContinueClicked(assetId: String, amountUsd: Decimal?)
    case depositFailed(PerpsDepositFailure, on: PerpsDepositStep)
    case depositConfirmed(from: PerpsDepositEntry, assetId: String, operationId: String)
    case orderSubmitted(PerpsOpeningDescriptor, clientOrderIndex: Int64)
    case tradingDataError(marketId: Int64)
}

public struct PerpsLoyalty {
    public let showsBanner: @MainActor () -> Bool
    public let reload: @MainActor () async -> Void
    public let hideBanner: @MainActor () -> Void
    public let reward: @MainActor (_ volumeUsd: Double) async throws -> String?

    public init(
        showsBanner: @escaping @MainActor () -> Bool,
        reload: @escaping @MainActor () async -> Void,
        hideBanner: @escaping @MainActor () -> Void,
        reward: @escaping @MainActor (_ volumeUsd: Double) async throws -> String?
    ) {
        self.showsBanner = showsBanner
        self.reload = reload
        self.hideBanner = hideBanner
        self.reward = reward
    }
}

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
    public let loyalty: PerpsLoyalty?
    /// Whether the wallets list holds another wallet that can deposit to Perps.
    public let hasOtherWallets: @MainActor () -> Bool
    public let track: (PerpsAnalyticsEvent) -> Void

    public init(
        accountStore: any PerpsAccountStoring,
        tradingService: any PerpsTradingService,
        activateAccount: @escaping PerpsAccountActivating,
        signingPasscode: @escaping PerpsSigningPasscodeProviding,
        recoverFunding: @escaping PerpsFundingRecovery,
        refreshFunding: @escaping PerpsFundingRefresh,
        makeDeposit: @escaping PerpsDepositProviding,
        makeWithdraw: @escaping PerpsWithdrawProviding = { nil },
        makeHistory: @escaping PerpsHistoryProviding,
        loyalty: PerpsLoyalty? = nil,
        hasOtherWallets: @escaping @MainActor () -> Bool = { true },
        track: @escaping (PerpsAnalyticsEvent) -> Void
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
        self.loyalty = loyalty
        self.hasOtherWallets = hasOtherWallets
        self.track = track
    }
}

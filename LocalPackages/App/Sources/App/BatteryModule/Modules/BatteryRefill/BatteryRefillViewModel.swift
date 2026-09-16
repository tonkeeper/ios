import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit

protocol BatteryRefillModuleOutput: AnyObject {
    var didTapSupportedTransactions: (() -> Void)? { get set }
    var didTapTransactionsSettings: (() -> Void)? { get set }
    var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)? { get set }
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)? { get set }
    var didFinish: (() -> Void)? { get set }
}

protocol BatteryRefillModuleInput: AnyObject {}

final class BatteryRefillViewModelImplementation: ObservableObject, BatteryRefillModuleOutput, BatteryRefillModuleInput {
    // MARK: - BatteryRefillModuleOutput

    var didTapSupportedTransactions: (() -> Void)?
    var didTapTransactionsSettings: (() -> Void)?
    var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)?
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?
    var didFinish: (() -> Void)?

    // MARK: - State

    struct HeaderState {
        let batteryState: BatterySwiftUIViewConfig.State
        let showsBetaTag: Bool
        let caption: String
        let warning: String?
        let showsSupportedTransactionsButton: Bool
    }

    struct InAppPurchaseRow: Identifiable {
        let id: String
        let title: String
        let caption: String
        let batteryPercent: CGFloat
        let buttonTitle: String
        let isEnabled: Bool
    }

    struct RechargeMethodRow: Identifiable {
        enum Icon {
            case ton
            case jetton(URL?)
            case gift
        }

        let id: String
        let title: String
        let caption: String?
        let icon: Icon
    }

    @Published private(set) var header: HeaderState?
    @Published private(set) var showsSettings = false
    @Published private(set) var inAppPurchaseRows = [InAppPurchaseRow]()
    @Published private(set) var rechargeMethodRows = [RechargeMethodRow]()
    @Published var showsCloseButton = false

    var showsRefillSections: Bool {
        !configuration.flag(\.batteryDisabled, network: wallet.network)
    }

    var footerDescription: String {
        configuration.flag(\.batteryDisabled, network: wallet.network)
            ? TKLocales.Battery.Refill.Footer.unavailable
            : TKLocales.Battery.Refill.Footer.description
    }

    var didTapClose: (() -> Void)?
    var endEditing: (() -> Void)?
    var endPromocodeEditing: (() -> Void)?

    private var rechargeMethodItems = [BatteryRefillRechargeMethodsModel.RechargeMethodItem]()
    private var promocode: String? {
        didSet {
            inAppPurchaseModel.promocode = promocode
        }
    }

    // MARK: - Dependencies

    private let wallet: Wallet
    private let inAppPurchaseModel: BatteryRefillIAPModel
    private let rechargeMethodsModel: BatteryRefillRechargeMethodsModel
    private let headerModel: BatteryRefillHeaderModel
    private let tonProofTokenService: TonProofTokenService
    private let configuration: Configuration
    private let amountFormatter: AmountFormatter
    private let promocodeOutput: BatteryPromocodeInputModuleOutput

    // MARK: - Init

    init(
        wallet: Wallet,
        inAppPurchaseModel: BatteryRefillIAPModel,
        rechargeMethodsModel: BatteryRefillRechargeMethodsModel,
        headerModel: BatteryRefillHeaderModel,
        tonProofTokenService: TonProofTokenService,
        configuration: Configuration,
        amountFormatter: AmountFormatter,
        promocodeOutput: BatteryPromocodeInputModuleOutput
    ) {
        self.wallet = wallet
        self.inAppPurchaseModel = inAppPurchaseModel
        self.rechargeMethodsModel = rechargeMethodsModel
        self.headerModel = headerModel
        self.tonProofTokenService = tonProofTokenService
        self.configuration = configuration
        self.amountFormatter = amountFormatter
        self.promocodeOutput = promocodeOutput
    }

    func viewDidLoad() {
        setupPromocode()

        headerModel.didUpdateState = { [weak self] state in
            self?.updateHeader(state: state)
        }
        updateHeader(state: headerModel.getState())

        updateInAppPurchaseRows(items: inAppPurchaseModel.items)
        inAppPurchaseModel.loadProducts()
        inAppPurchaseModel.loadPurchasesAvailability()
        inAppPurchaseModel.eventHandler = { [weak self] event in
            switch event {
            case let .didUpdateItems(items):
                self?.updateInAppPurchaseRows(items: items)
            case .didPerformTransaction:
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Battery.Refill.Toast.recharged))
            case let .didFailTransaction(error: error):
                Log.e("battery refill didFailTransaction", extraInfo: [
                    "error": error?.localizedDescription ?? "unknown error",
                ])
            }
        }

        updateRechargeMethodRows(state: rechargeMethodsModel.state)
        rechargeMethodsModel.stateHandler = { [weak self] state in
            self?.updateRechargeMethodRows(state: state)
        }
        rechargeMethodsModel.loadMethods()
    }

    // MARK: - Actions

    func purchase(productIdentifier: String) {
        inAppPurchaseModel.startProcessing(identifier: productIdentifier)
    }

    func selectRechargeMethod(id: String) {
        guard let item = rechargeMethodItems.first(where: { $0.identifier == id }) else { return }
        endPromocodeEditing?()
        didTapRecharge?(item)
    }

    func openSettings() {
        endPromocodeEditing?()
        didTapTransactionsSettings?()
    }

    func openHistory() {
        endPromocodeEditing?()
        guard let url = createRefundURL() else { return }
        didOpenRefundURL?(url, TKLocales.Battery.Refill.ChargesHistory.title)
    }

    func openSupportedTransactions() {
        didTapSupportedTransactions?()
    }

    func close() {
        didTapClose?()
    }

    func restorePurchases() {
        ToastPresenter.showToast(configuration: .loading)
        Task { @MainActor [weak self] in
            guard let self else {
                ToastPresenter.hideAll()
                return
            }
            let result = await self.inAppPurchaseModel.restorePurchases()

            ToastPresenter.hideAll()

            switch result {
            case .success:
                ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.restored))
            case let .failure(error):
                switch error {
                case .nothingToRestore:
                    ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.nothingToRestore))
                default:
                    ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.failed(error.rawValue)))
                }
            }
        }
    }

    // MARK: - State updates

    private func updateHeader(state: BatteryRefillHeaderModel.State) {
        switch state.charge {
        case let .charged(chargesCount, batteryPercent):
            header = HeaderState(
                batteryState: .fill(batteryPercent),
                showsBetaTag: state.isBeta,
                caption: chargesCaption(chargesCount: chargesCount),
                warning: nil,
                showsSupportedTransactionsButton: false
            )
            showsSettings = true
        case let .refunded(chargesCount):
            header = HeaderState(
                batteryState: .negative,
                showsBetaTag: state.isBeta,
                caption: chargesCaption(chargesCount: chargesCount),
                warning: TKLocales.Battery.Refill.negativeBalanceCaption,
                showsSupportedTransactionsButton: false
            )
            showsSettings = true
        case .notCharged:
            header = HeaderState(
                batteryState: .emptyTinted,
                showsBetaTag: state.isBeta,
                caption: TKLocales.Battery.Refill.emptyCaption,
                warning: nil,
                showsSupportedTransactionsButton: true
            )
            showsSettings = false
        }
    }

    private func chargesCaption(chargesCount: Int) -> String {
        "\(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: abs(chargesCount)))"
    }

    private func updateInAppPurchaseRows(items: [BatteryIAPItem]) {
        inAppPurchaseRows = items.map { item in
            let caption: String
            let buttonTitle: String
            switch item.state {
            case .loading:
                caption = "Loading"
                buttonTitle = "Loading"
            case let .amount(amount):
                caption = "\(amount.charges) \(TKLocales.Battery.Refill.chargesCount(count: amount.charges))"
                buttonTitle = amountFormatter.format(
                    decimal: amount.price,
                    accessory: .fiat(amount.currency),
                    style: .compact
                )
            }

            return InAppPurchaseRow(
                id: item.pack.productIdentifier,
                title: item.pack.name,
                caption: caption,
                batteryPercent: item.pack.batteryPercent,
                buttonTitle: buttonTitle,
                isEnabled: item.isEnable
            )
        }
    }

    private func updateRechargeMethodRows(state: BatteryRefillRechargeMethodsModel.State) {
        switch state {
        case .loading:
            rechargeMethodItems = []
        case let .idle(items):
            rechargeMethodItems = items
        }

        rechargeMethodRows = rechargeMethodItems.map { item in
            switch item {
            case let .token(token):
                let icon: RechargeMethodRow.Icon
                switch token {
                case .ton:
                    icon = .ton
                case let .jetton(jettonItem):
                    icon = .jetton(jettonItem.jettonInfo.imageURL)
                }
                return RechargeMethodRow(
                    id: item.identifier,
                    title: "\(TKLocales.Battery.Refill.Crypto.recharge) \(token.symbol)",
                    caption: nil,
                    icon: icon
                )
            case .gift:
                return RechargeMethodRow(
                    id: item.identifier,
                    title: TKLocales.Battery.Refill.Gift.title,
                    caption: TKLocales.Battery.Refill.Gift.caption,
                    icon: .gift
                )
            }
        }
    }

    private func createRefundURL() -> URL? {
        guard let tonProof = try? tonProofTokenService.getWalletToken(wallet),
              let batteryRefundEndpoint = configuration.batteryRefundEndpoint(network: wallet.network)
        else {
            return nil
        }

        var components = URLComponents(url: batteryRefundEndpoint, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "token", value: tonProof),
            URLQueryItem(name: "testnet", value: String(wallet.network == .testnet)),
        ]
        return components?.url
    }

    private func setupPromocode() {
        promocodeOutput.didUpdateResolvingState = { [weak self] state in
            switch state {
            case .failed, .none, .resolving:
                self?.promocode = nil
            case let .success(promocode):
                self?.promocode = promocode
            }
        }
    }
}

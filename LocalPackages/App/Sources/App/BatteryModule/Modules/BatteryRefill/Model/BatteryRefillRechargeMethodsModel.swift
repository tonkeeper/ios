import BigInt
import Foundation
import KeeperCore
import TKFeatureFlags
import TonSwift

final class BatteryRefillRechargeMethodsModel {
    enum RechargeMethodItem {
        case token(token: TonToken)
        case gift(token: TonToken)

        var identifier: String {
            switch self {
            case let .token(token):
                return token.identifier
            case .gift:
                return "gift_identifier"
            }
        }

        var token: TonToken {
            switch self {
            case let .token(token):
                return token
            case let .gift(token):
                return token
            }
        }
    }

    enum State {
        case loading
        case idle(items: [RechargeMethodItem])
    }

    var stateHandler: ((State) -> Void)?
    private(set) var state: State = .loading {
        didSet {
            stateHandler?(state)
        }
    }

    private var rechargeMethods = [RechargeMethodItem]()
    private var loadingTask: Task<Void, Never>?
    private var isLoading: Bool {
        loadingTask == nil
    }

    private let wallet: Wallet
    private let rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider
    private let configuration: Configuration

    init(
        wallet: Wallet,
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.rechargeMethodsProvider = rechargeMethodsProvider
        self.configuration = configuration
    }

    func loadMethods() {
        guard !configuration.isDisableBatteryCryptoRechargeModule(network: wallet.network) else {
            state = .idle(items: [])
            return
        }

        if let loadingTask = loadingTask {
            loadingTask.cancel()
        }
        let task = Task { [weak self] in
            guard let self else { return }
            let methods = await rechargeMethodsProvider.getAllRechargeMethods()
            await MainActor.run {
                self.rechargeMethods = methods
                self.loadingTask = nil
                self.state = .idle(items: methods)
            }
        }
        self.loadingTask = task
    }
}

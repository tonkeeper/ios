import Foundation
import KeeperCore
import TKCoordinator

struct P2PExpressParams {
    let wallet: String
    let network: String
    let cryptoCurrency: String
    let fiatCurrency: String
    let amount: Int64?
    let requestNetwork: Network

    var createP2PSession: CreateP2PSession {
        CreateP2PSession(
            wallet: wallet,
            network: network,
            cryptoCurrency: cryptoCurrency,
            fiatCurrency: fiatCurrency,
            amount: amount
        )
    }
}

@MainActor
struct P2PExpressModule {
    private let dependencies: Dependencies

    init(
        dependencies: Dependencies
    ) {
        self.dependencies = dependencies
    }

    func createP2PExpressCoordinator(
        router: ViewControllerRouter,
        params: P2PExpressParams
    ) -> P2PExpressCoordinator {
        return P2PExpressCoordinator(
            params: params,
            router: router,
            onRampService: dependencies.onRampService,
            doNotShowAgainStore: P2PExpressUserDefaultsDoNotShowAgainStore(
                userDefaults: .standard
            )
        )
    }
}

extension P2PExpressModule {
    struct Dependencies {
        let onRampService: OnRampService
    }
}

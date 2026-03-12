import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

enum SendAnalyticsSource {
    case walletScreen
    case jettonScreen
    case deepLink
    case tonconnectLocal(appId: String)
    case tonconnectRemote
    case qrCode
}

@MainActor
struct SendModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createSendTokenCoordinator(
        router: NavigationControllerRouter,
        wallet: Wallet,
        sendItem: SendV3Item,
        sendSource: SendAnalyticsSource,
        recipient: Recipient? = nil,
        comment: String? = nil
    ) -> SendTokenCoordinator {
        return SendTokenCoordinator(
            router: router,
            wallet: wallet,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
            sendItem: sendItem,
            sendSource: sendSource,
            recipient: recipient,
            comment: comment
        )
    }
}

extension SendModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}

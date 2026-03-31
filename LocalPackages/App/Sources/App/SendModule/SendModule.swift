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
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        recipient: Recipient? = nil,
        comment: String? = nil
    ) -> SendTokenCoordinator {
        SendTokenCoordinator(
            router: router,
            wallet: wallet,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
            sendInput: sendInput,
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

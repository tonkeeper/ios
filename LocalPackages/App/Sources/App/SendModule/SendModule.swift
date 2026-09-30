import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKUIKit

enum SendAnalyticsSource {
    case walletScreen
    case jettonScreen
    case deepLink(utm: UtmParameters)
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
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: LegacyRecipient? = nil,
        comment: String? = nil
    ) -> any SendCoordinator {
        LegacySendTokenCoordinator(
            router: router,
            wallet: wallet,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
            sendInput: sendInput,
            sendSource: sendSource,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            recipient: recipient,
            comment: comment
        )
    }

    func createMultichainSendCoordinator(
        router: NavigationControllerRouter,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        entry: MultichainSendEntry,
        sendSource: SendAnalyticsSource,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: MultichainRecipient? = nil,
        comment: String? = nil
    ) -> (any SendCoordinator)? {
        guard wallet.isMultichain else {
            return nil
        }
        return MultichainSendCoordinator(
            router: router,
            wallet: wallet,
            multichainState: multichainState,
            entry: entry,
            sendSource: sendSource,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
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

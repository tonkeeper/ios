import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import UIKit

final class BackupCheckCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let wallet: Wallet
    private let phrase: [String]
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let source: BackupSource

    init(
        wallet: Wallet,
        phrase: [String],
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        source: BackupSource,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.phrase = phrase
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.source = source
        super.init(router: router)
    }

    override func start() {
        var provider = BackupRecoveryPhraseDataProvider(
            phrase: phrase
        )

        provider.didTapNext = { [weak self] in
            self?.openCheckInput()
        }

        let module = TKRecoveryPhraseAssembly.module(
            provider: provider
        )

        if router.rootViewController.viewControllers.isEmpty {
            module.viewController.setupHeaderCloseButton { [weak self] in
                self?.didFinish?(self)
            }
        } else {
            module.viewController.setupHeaderBackButton()
        }

        router.push(viewController: module.viewController, onPopClosures: { [weak self] in
            self?.didFinish?(self)
        })
    }

    func openCheckInput() {
        let module = TKCheckRecoveryPhraseAssembly.module(
            provider: BackupCheckRecoveryPhraseProvider(
                phrase: phrase
            )
        )

        module.output.didCheckRecoveryPhrase = { [weak self] in
            guard let self else { return }
            Task {
                await self.setDidBackup()
                self.coreAssembly.analyticsProvider.log(
                    WalletBackupSuccess(walletMode: WalletMode(wallet: self.wallet), source: self.source)
                )
                self.coreAssembly.analyticsProvider.logSeedBackupConfirmed()
                await MainActor.run(body: {
                    self.didFinish?(self)
                })
            }
        }
        module.output.didFailCheckRecoveryPhrase = { [weak self] in
            guard let self else { return }
            coreAssembly.analyticsProvider.logWalletBackupMismatch(
                walletMode: WalletMode(wallet: wallet),
                source: source
            )
        }

        module.viewController.setupHeaderBackButton()

        router.push(viewController: module.viewController)
    }

    func setDidBackup() async {
        await keeperCoreMainAssembly.storesAssembly.walletsStore.setWalletBackupDate(
            wallet: wallet, backupDate: Date()
        )
    }
}

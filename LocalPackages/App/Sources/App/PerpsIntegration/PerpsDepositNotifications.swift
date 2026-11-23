import KeeperCore
import Perps
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class PerpsDepositNotifications {
    private let mainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private var scope: PerpsWalletScope?
    private var status: PerpsDepositStatusViewModel?
    private var recoveryTask: Task<Void, Never>?

    init(mainAssembly: KeeperCore.MainAssembly, coreAssembly: TKCore.CoreAssembly) {
        self.mainAssembly = mainAssembly
        self.coreAssembly = coreAssembly
        mainAssembly.storesAssembly.walletsStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.updateWallet() }
        }
        updateWallet()
    }

    deinit {
        recoveryTask?.cancel()
    }

    private func updateWallet() {
        let wallet = try? mainAssembly.storesAssembly.walletsStore.activeWallet
        guard wallet != scope?.wallet else { return }
        recoveryTask?.cancel()
        recoveryTask = nil
        status?.onCompleted = nil
        status = nil
        scope = nil
        guard let wallet, wallet.isMultichain else { return }
        let scope = mainAssembly.perpsAssembly.walletScope(for: wallet)
        self.scope = scope
        let status = PerpsDepositStatusViewModel(
            accountStore: scope.accountStore,
            format: .live(appSettingsStore: mainAssembly.storesAssembly.appSettingsStore)
        )
        status.isVisible = false
        status.onCompleted = { [weak self] in
            guard let self, self.scope?.wallet == wallet,
                  (try? mainAssembly.storesAssembly.walletsStore.activeWallet) == wallet else { return }
            ToastPresenter.showToast(configuration: .init(
                title: TKLocales.Perps.DepositStatus.completed,
                icon: .TKUIKit.Icons.Size16.checkmarkCircle,
                iconTintColor: .Accent.green,
                feedback: .success
            ))
        }
        self.status = status
        recoveryTask = Task { [appState = coreAssembly.appStateTracker, reachability = coreAssembly.reachabilityTracker] in
            let lifecycle = PerpsFundingLifecycle(appState: appState, reachability: reachability)
            await scope.recoverFunding(while: lifecycle.states)
        }
    }
}

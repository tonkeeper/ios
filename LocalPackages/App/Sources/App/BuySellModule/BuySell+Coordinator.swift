import UIKit
import SwiftUI
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class BuySellCoordinator: RouterCoordinator<ViewControllerRouter> {
    
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    
    init(wallet: Wallet,
         keeperCoreMainAssembly: KeeperCore.MainAssembly,
         coreAssembly: TKCore.CoreAssembly,
         router: ViewControllerRouter) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }
    
    public override func start() {
        openBuySell()
    }
}

private extension BuySellCoordinator {
    func openBuySell() {
        let vm = BuySellVM(
            main: Color(UIColor.Button.primaryBackground),
            layer1: Color(UIColor.Background.page),
            layer2: Color(UIColor.Button.secondaryBackground),
            layer3: Color.red,
            mainLabel: Color(UIColor.Text.primary),
            secondaryLabel: Color(UIColor.Text.secondary)
        )
        vm.didTapDismiss = { [weak self] in
            self?.router.dismiss()
        }
        
        let buyView = BuySell(vm: vm)
        let buyViewHosting = UIHostingController(rootView: buyView)
        let navigationView = UINavigationController(rootViewController: buyViewHosting)
        
        navigationView.isNavigationBarHidden = true
        router.present(navigationView)
    }
}

//
//  File.swift
//
//
//  Created by davidtam on 23/5/24.
//

import UIKit
import SwiftUI
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class SwapCoordinator: RouterCoordinator<ViewControllerRouter> {
    
//    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    
    init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
         coreAssembly: TKCore.CoreAssembly,
         router: ViewControllerRouter) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }
    
    public override func start() {
        openSwap()
    }
}

private extension SwapCoordinator {
    func openSwap() {
        let vm = SwapVM(
            main: Color(UIColor.Button.primaryBackground),
            layer1: Color(UIColor.Background.page),
            layer2: Color(UIColor.Button.secondaryBackground),
            layer3: Color(UIColor.Button.tertiaryBackground),
            mainLabel: Color(UIColor.Text.primary),
            secondaryLabel: Color(UIColor.Text.secondary)
        )
        vm.didTapDismiss = { [weak self] in
            self?.router.dismiss()
        }
        
        let swapView = Swap(vm: vm)
        let swapViewHosting = UIHostingController(rootView: swapView)
        let navigationView = UINavigationController(rootViewController: swapViewHosting)
        
        navigationView.isNavigationBarHidden = true
        router.present(navigationView)
    }
}

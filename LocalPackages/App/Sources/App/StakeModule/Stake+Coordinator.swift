//
//  File.swift
//  
//
//  Created by davidtam on 24/5/24.
//

import UIKit
import SwiftUI
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class StakeCoordinator: RouterCoordinator<ViewControllerRouter> {
    
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
        openStake()
    }
}

private extension StakeCoordinator {
    func openStake() {
        let vm = StakeViewModel(
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
        
        let stakeView = Stake(vm: vm)
        let stakeViewHosting = UIHostingController(rootView: stakeView)
        let navigationView = UINavigationController(rootViewController: stakeViewHosting)
        
        navigationView.isNavigationBarHidden = true
        router.present(navigationView)
    }
}

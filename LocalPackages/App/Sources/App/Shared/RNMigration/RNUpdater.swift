import Foundation
import TKUIKit
import KeeperCore

actor RNUpdater {
  private let rnService: RNService
  private let keeperInfoStore: KeeperInfoStore

  init(rnService: RNService,
       keeperInfoStore: KeeperInfoStore) {
    self.rnService = rnService
    self.keeperInfoStore = keeperInfoStore
    
    keeperInfoStore.addObserver(self) { observer, event in
      Task {
        await observer.updateWalletsStore()
      }
    }
    
    TKThemeManager.shared.addEventObserver(self) { observer, theme in
      Task {
        let appTheme = RNAppTheme(state: RNAppTheme.State(selectedTheme: theme.rawValue))
        try await rnService.setAppTheme(appTheme)
      }
    }
  }

  private func updateWalletsStore() async {
    guard let keeperInfo = keeperInfoStore.state else {
      try? await rnService.setWallets([])
      return
    }
    
    let wallets = keeperInfo.wallets.map { RNWallet(wallet: $0) }
    let selectedIdentifier = keeperInfo.currentWallet.id
    let biometryEnabled = keeperInfo.securitySettings.isBiometryEnabled
    let lockScreenEnabled = keeperInfo.securitySettings.isLockScreen
    
    try? await rnService.setWallets(wallets)
    try? await rnService.setActiveWalletId(selectedIdentifier)
    try? await rnService.setIsBiometryEnable(biometryEnabled)
    try? await rnService.setIsLockscreenEnable(lockScreenEnabled)
  }
}

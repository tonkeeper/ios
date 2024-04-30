extension KeeperInfo {
  func setWallets(_ wallets: [Wallet]) -> KeeperInfo {
    KeeperInfo(
      wallets: wallets,
      currentWallet: self.currentWallet,
      currency: self.currency,
      securitySettings: self.securitySettings,
      isSetupFinished: self.isSetupFinished,
      assetsPolicy: self.assetsPolicy,
      appCollection: self.appCollection
    )
  }
  
  func setActiveWallet(_ wallet: Wallet) -> KeeperInfo {
    KeeperInfo(
      wallets: self.wallets,
      currentWallet: wallet,
      currency: self.currency,
      securitySettings: self.securitySettings,
      isSetupFinished: self.isSetupFinished,
      assetsPolicy: self.assetsPolicy,
      appCollection: self.appCollection
    )
  }
  
  func setWallets(_ wallets: [Wallet], 
                  activeWallet: Wallet) -> KeeperInfo {
    KeeperInfo(
      wallets: wallets,
      currentWallet: activeWallet,
      currency: self.currency,
      securitySettings: self.securitySettings,
      isSetupFinished: self.isSetupFinished,
      assetsPolicy: self.assetsPolicy,
      appCollection: self.appCollection
    )
  }
}

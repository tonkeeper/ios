extension KeeperInfo {
  func setCurrency(_ currency: Currency) -> KeeperInfo {
    KeeperInfo(
      wallets: self.wallets,
      currentWallet: self.currentWallet,
      currency: currency,
      securitySettings: self.securitySettings,
      isSetupFinished: self.isSetupFinished,
      assetsPolicy: self.assetsPolicy,
      appCollection: self.appCollection
    )
  }
}

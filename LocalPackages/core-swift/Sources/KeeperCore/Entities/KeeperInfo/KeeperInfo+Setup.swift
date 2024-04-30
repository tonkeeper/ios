extension KeeperInfo {
  func setIsSetupFinished(_ isSetupFinished: Bool) -> KeeperInfo {
    KeeperInfo(
      wallets: wallets,
      currentWallet: currentWallet,
      currency: currency,
      securitySettings: securitySettings,
      isSetupFinished: isSetupFinished,
      assetsPolicy: assetsPolicy,
      appCollection: appCollection
    )
  }
}

extension KeeperInfo {
  func setIsBiometryEnabled(_ isOn: Bool) -> KeeperInfo {
    KeeperInfo(
      wallets: wallets,
      currentWallet: currentWallet,
      currency: currency,
      securitySettings: SecuritySettings(isBiometryEnabled: isOn),
      isSetupFinished: isSetupFinished,
      assetsPolicy: assetsPolicy,
      appCollection: appCollection
    )
  }
}

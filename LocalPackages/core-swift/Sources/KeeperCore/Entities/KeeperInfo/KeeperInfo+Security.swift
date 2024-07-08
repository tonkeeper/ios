extension KeeperInfo {
  func setIsBiometryEnabled(_ isOn: Bool) -> KeeperInfo {
    let securitySettings = SecuritySettings(
      isBiometryEnabled: isOn,
      isLockScreen: securitySettings.isLockScreen
    )
    
    return KeeperInfo(
      wallets: wallets,
      currentWallet: currentWallet,
      currency: currency,
      securitySettings: securitySettings,
      isSetupFinished: isSetupFinished,
      assetsPolicy: assetsPolicy,
      appCollection: appCollection
    )
  }
  
  func setIsLockScreen(_ isOn: Bool) -> KeeperInfo {
    let securitySettings = SecuritySettings(
      isBiometryEnabled: securitySettings.isBiometryEnabled,
      isLockScreen: isOn
    )
    
    return KeeperInfo(
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

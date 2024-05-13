extension SignerInfo {
  func setIsBiometryEnabled(_ isOn: Bool) -> SignerInfo {
    SignerInfo(
      walletKeys: walletKeys,
      securitySettings: SecuritySettings(isBiometryEnabled: isOn),
      isSetupFinished: isSetupFinished
    )
  }
}

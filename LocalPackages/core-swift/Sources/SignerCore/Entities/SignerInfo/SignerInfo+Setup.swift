extension SignerInfo {
  func setIsSetupFinished(_ isSetupFinished: Bool) -> SignerInfo {
    SignerInfo(
      walletKeys: walletKeys,
      securitySettings: securitySettings,
      isSetupFinished: isSetupFinished
    )
  }
}

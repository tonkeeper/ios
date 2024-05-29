extension SignerInfo {
  func setWalletKeys(_ walletKeys: [WalletKey]) -> SignerInfo {
    SignerInfo(
      walletKeys: walletKeys,
      securitySettings: self.securitySettings,
      isSetupFinished: self.isSetupFinished
    )
  }
}

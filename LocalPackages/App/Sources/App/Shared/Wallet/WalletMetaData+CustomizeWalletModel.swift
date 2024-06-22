import Foundation
import KeeperCore

extension WalletMetaData {
  init(customizeWalletModel: CustomizeWalletModel) {
    self.init(
      label: customizeWalletModel.name,
      tintColor: customizeWalletModel.tintColor,
      icon: .emoji(customizeWalletModel.emoji)
    )
  }
}

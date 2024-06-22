import Foundation

enum WalletsListSection: Hashable {
  case wallets
  case addWallet
}

enum WalletsListItem: Hashable {
  case wallet(String)
  case addWalletButton(String)
}

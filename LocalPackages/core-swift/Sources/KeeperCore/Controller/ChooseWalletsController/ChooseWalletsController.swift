import Foundation
import TonSwift
import BigInt
import TKLocalize

public final class ChooseWalletsController {
  public struct WalletModel: Equatable {
    public let identifier: String
    public let address: String
    public let subtitle: String
    public let isSelected: Bool
    public let isEnable: Bool
  }
  
  public var models: [WalletModel] {
    getModels()
  }
  
  private let activeWalletModels: [ActiveWalletModel]
  private let amountFormatter: AmountFormatter
  private let isLedger: Bool
  
  init(activeWalletModels: [ActiveWalletModel],
       isLedger: Bool,
       amountFormatter: AmountFormatter) {
    self.activeWalletModels = activeWalletModels.sorted(by: { isLedger ? $0.ledgerIndex < $1.ledgerIndex : $0.revision > $1.revision })
    self.isLedger = isLedger
    self.amountFormatter = amountFormatter
  }
  
  public func revisions(indexes: [Int]) -> [WalletContractVersion] {
    indexes
      .filter { activeWalletModels.count > $0 }
      .map { activeWalletModels[$0] }
      .map { $0.revision }
  }
  
  public func walletModels(indexes: [Int]) -> [ActiveWalletModel] {
    indexes
      .filter { activeWalletModels.count > $0 }
      .map { activeWalletModels[$0] }
  }
}

private extension ChooseWalletsController {
  func getModels() -> [WalletModel] {
    activeWalletModels
      .map { mapActiveWallet($0) }
  }
  
  func mapActiveWallet(_ activeWallet: ActiveWalletModel) -> WalletModel {
    let tonAmount = amountFormatter.formatAmount(
      BigUInt(
        integerLiteral: UInt64(activeWallet.balance.tonBalance.amount)
      ),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      currency: .TON
    )
    let identifier = activeWallet.address.toRaw()
    let address = activeWallet.address.toShortString(bounceable: false)
    var subtitle = isLedger ? tonAmount : "\(activeWallet.revision.rawValue) · \(tonAmount)"
    if !activeWallet.balance.jettonsBalance.isEmpty || !activeWallet.nfts.isEmpty {
      subtitle.append(", " + TKLocales.ChooseWallets.tokens)
    }
    if (activeWallet.isLedgerAdded) {
      subtitle.append(" · " + TKLocales.ChooseWallets.alreadyAdded)
    }
    
    let isEnable: Bool = {
      guard isLedger else { return true }
      return !activeWallet.isLedgerAdded
    }()
    let isSelected: Bool = {
      guard isEnable else { return false }
      if isLedger {
        return !activeWallet.isLedgerAdded && !activeWallet.balance.isEmpty
      } else {
        return activeWallet.revision == .currentVersion || !activeWallet.balance.isEmpty
      }
    }()
    
    return WalletModel(
      identifier: identifier,
      address: address,
      subtitle: subtitle,
      isSelected: isSelected,
      isEnable: isEnable
    )
  }
}

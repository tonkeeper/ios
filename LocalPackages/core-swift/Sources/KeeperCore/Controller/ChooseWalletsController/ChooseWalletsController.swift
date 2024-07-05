import Foundation
import TonSwift
import BigInt
import TKLocalize

public final class ChooseWalletsController {
  public struct Configuration {
    public let showRevision: Bool
    public let selectLastRevision: Bool
    
    public init(showRevision: Bool, selectLastRevision: Bool) {
      self.showRevision = showRevision
      self.selectLastRevision = selectLastRevision
    }
  }
  
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
  private let configuration: Configuration
  
  init(activeWalletModels: [ActiveWalletModel],
       amountFormatter: AmountFormatter,
       configuration: Configuration) {
    self.activeWalletModels = activeWalletModels
    self.amountFormatter = amountFormatter
    self.configuration = configuration
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
    var subtitle = !configuration.showRevision ? tonAmount : "\(activeWallet.revision.rawValue) · \(tonAmount)"
    if !activeWallet.balance.jettonsBalance.isEmpty || !activeWallet.nfts.isEmpty {
      subtitle.append(", " + TKLocales.ChooseWallets.tokens)
    }
    if (activeWallet.isAdded) {
      subtitle.append(" · " + TKLocales.ChooseWallets.alreadyAdded)
    }
    
    let isEnable = !activeWallet.isAdded
    let isSelected: Bool = {
      guard isEnable else { return false }
      return !activeWallet.balance.isEmpty || (activeWallet.revision == .currentVersion && configuration.selectLastRevision)
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

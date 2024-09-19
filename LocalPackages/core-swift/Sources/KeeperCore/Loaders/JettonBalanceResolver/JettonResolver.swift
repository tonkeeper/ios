import Foundation
import TonSwift

public enum JettonBalanceResolverError: Swift.Error {
  case insufficientFunds(jettonAddress: Address, wallet: Wallet)
}

public protocol JettonBalanceResolver {
  func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonItem
}

public struct JettonBalanceResolverImplementation: JettonBalanceResolver {
  
  private let balanceStore: BalanceStore
  
  public init(balanceStore: BalanceStore) {
    self.balanceStore = balanceStore
  }
  
  public func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonItem {
    guard let balance = await balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance else {
      throw JettonBalanceResolverError.insufficientFunds(jettonAddress: jettonAddress, wallet: wallet)
    }
    
    guard let jettonItem = balance.first(where: { $0.item.jettonInfo.address == jettonAddress })?.item else {
      throw JettonBalanceResolverError.insufficientFunds(jettonAddress: jettonAddress, wallet: wallet)
    }
    
    return jettonItem
  }
}

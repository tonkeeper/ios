import Foundation
import TonSwift

public enum JettonBalanceResolverError: Swift.Error {
  case unknownJetton
  case insufficientFunds(jettonInfo: JettonInfo, wallet: Wallet)
}

public protocol JettonBalanceResolver {
  func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonItem
}

public struct JettonBalanceResolverImplementation: JettonBalanceResolver {
  
  private let balanceStore: BalanceStore
  private let apiProvider: APIProvider
  
  init(balanceStore: BalanceStore,
       apiProvider: APIProvider) {
    self.balanceStore = balanceStore
    self.apiProvider = apiProvider
  }
  
  public func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonItem {
    let jettonInfo: JettonInfo
    do {
      jettonInfo = try await apiProvider.api(wallet.isTestnet).resolveJetton(address: jettonAddress)
    } catch {
      throw JettonBalanceResolverError.unknownJetton
    }

    guard let balance = await balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance else {
      throw JettonBalanceResolverError.insufficientFunds(jettonInfo: jettonInfo, wallet: wallet)
    }
    
    guard let jettonItem = balance.first(where: { $0.item.jettonInfo.address == jettonAddress })?.item else {
      throw JettonBalanceResolverError.insufficientFunds(jettonInfo: jettonInfo, wallet: wallet)
    }
    
    return jettonItem
  }
}

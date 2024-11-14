import Foundation
import TonSwift
import BigInt

public enum JettonBalanceResolverError: Swift.Error {
  case unknownJetton
  case insufficientFunds(jettonInfo: JettonInfo, balance: BigUInt, wallet: Wallet)
}

public protocol JettonBalanceResolver {
  func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonBalance
}

public struct JettonBalanceResolverImplementation: JettonBalanceResolver {
  
  private let balanceStore: BalanceStore
  private let apiProvider: APIProvider
  
  init(balanceStore: BalanceStore,
       apiProvider: APIProvider) {
    self.balanceStore = balanceStore
    self.apiProvider = apiProvider
  }
  
  public func resolveJetton(jettonAddress: Address, wallet: Wallet) async throws -> JettonBalance {
    let jettonInfo: JettonInfo
    do {
      jettonInfo = try await apiProvider.api(wallet.isTestnet).resolveJetton(address: jettonAddress)
    } catch {
      throw JettonBalanceResolverError.unknownJetton
    }

    guard let balance = balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance else {
      throw JettonBalanceResolverError.insufficientFunds(jettonInfo: jettonInfo, balance: 0, wallet: wallet)
    }
    
    guard let jettonBalance = balance.first(where: { $0.item.jettonInfo.address == jettonAddress }) else {
      throw JettonBalanceResolverError.insufficientFunds(jettonInfo: jettonInfo, balance: 0, wallet: wallet)
    }
    
    return jettonBalance
  }
}

import Foundation
import TonAPI
import TonSwift

public protocol SendService {
  func loadSeqno(wallet: Wallet) async throws -> UInt64
  func loadTransactionInfo(boc: String, wallet: Wallet) async throws -> Components.Schemas.MessageConsequences
  func sendTransaction(boc: String, wallet: Wallet) async throws
}

final class SendServiceImplementation: SendService {
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func loadSeqno(wallet: Wallet) async throws -> UInt64 {
    try await UInt64(apiProvider.api(wallet.isTestnet).getSeqno(address: wallet.address))
  }
  
  func loadTransactionInfo(boc: String, wallet: Wallet) async throws -> Components.Schemas.MessageConsequences {
    try await apiProvider.api(wallet.isTestnet)
      .emulateMessageWallet(boc: boc)
  }
  
  func sendTransaction(boc: String, wallet: Wallet) async throws {
    try await apiProvider.api(wallet.isTestnet)
      .sendTransaction(boc: boc)
  }
}

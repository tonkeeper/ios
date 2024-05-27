import Foundation

public final class TonConnectConfirmTransactionControllerBocProvider: ConfirmTransactionControllerBocProvider {
  
  public enum Error: Swift.Error {
    case emptyParams
  }
  
  private let signTransactionParams: [SendTransactionParam]
  private let tonConnectService: TonConnectService
  
  init(signTransactionParams: [SendTransactionParam], 
       tonConnectService: TonConnectService) {
    self.signTransactionParams = signTransactionParams
    self.tonConnectService = tonConnectService
  }
  
  public func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String {
    guard let appRequestParam = signTransactionParams.first else {
      throw Error.emptyParams
    }
    return try await tonConnectService.createEmulateRequestBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: appRequestParam
    )
  }
}

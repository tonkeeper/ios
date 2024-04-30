import Foundation
import TonSwift

struct TonConnectResponseBuilder {
  static func buildConnectEventSuccesResponse(requestPayloadItems: [TonConnectRequestPayload.Item],
                                              wallet: Wallet,
                                              sessionCrypto: TonConnectSessionCrypto,
                                              walletPrivateKey: TonSwift.PrivateKey,
                                              manifest: TonConnectManifest,
                                              clientId: String) throws -> String {
    let address = try wallet.address
    
    let replyItems = try requestPayloadItems.compactMap { item in
      switch item {
      case .tonAddress:
        return TonConnect.ConnectItemReply.tonAddress(.init(
          address: address,
          network: wallet.identity.network,
          publicKey: try wallet.publicKey,
          walletStateInit: try wallet.stateInit)
        )
      case .tonProof(let payload):
        return TonConnect.ConnectItemReply.tonProof(.success(.init(
          address: address,
          domain: manifest.host,
          payload: payload,
          privateKey: walletPrivateKey
        )))
      case .unknown:
        return nil
      }
    }
    let successEvent = TonConnect.ConnectEventSuccess(
      payload: .init(items: replyItems,
                     device: .init())
    )
    let responseData = try JSONEncoder().encode(successEvent)
    guard let receiverPublicKey = Data(hex: clientId) else { return "" }
    let response = try sessionCrypto.encrypt(
      message: responseData,
      receiverPublicKey: receiverPublicKey
    )
    return response.base64EncodedString()
  }
  
  static func buildSendTransactionResponseSuccess(
    sessionCrypto: TonConnectSessionCrypto,
    boc: String,
    id: String,
    clientId: String
  ) throws -> String {
    let response = TonConnect.SendTransactionResponse.success(
      .init(result: boc,
            id: id)
    )
    let transactionResponseData = try JSONEncoder().encode(response)
    guard let receiverPublicKey = Data(hex: clientId) else { return "" }
    
    let encryptedTransactionResponse = try sessionCrypto.encrypt(
      message: transactionResponseData,
      receiverPublicKey: receiverPublicKey
    )
    
    return encryptedTransactionResponse.base64EncodedString()
  }
  
  static func buildSendTransactionResponseError(
    sessionCrypto: TonConnectSessionCrypto,
    errorCode: TonConnect.SendTransactionResponseError.ErrorCode,
    id: String,
    clientId: String
  ) throws -> String {
    let response = TonConnect.SendTransactionResponse.error(
      .init(id: id,
            error: .init(code: errorCode,
                         message: "")
           )
    )
    let transactionResponseData = try JSONEncoder().encode(response)
    guard let receiverPublicKey = Data(hex: clientId) else { return "" }
    
    let encryptedTransactionResponse = try sessionCrypto.encrypt(
      message: transactionResponseData,
      receiverPublicKey: receiverPublicKey
    )
    
    return encryptedTransactionResponse.base64EncodedString()
  }
}

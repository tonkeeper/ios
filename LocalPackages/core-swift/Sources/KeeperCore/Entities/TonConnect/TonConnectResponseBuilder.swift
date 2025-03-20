import Foundation
import TonSwift

public struct TonConnectResponseBuilder {
  static func buildReconnectConnectEventSuccessResponse(wallet: Wallet,
                                                        keeperVersion: String,
                                                        manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess {
    let address = try wallet.address
    
    let replyItems = [TonConnect.ConnectItemReply.tonAddress(.init(
      address: address,
      network: wallet.identity.network,
      publicKey: try wallet.publicKey,
      walletStateInit: try wallet.stateInit)
    )]
    
    let successEvent = TonConnect.ConnectEventSuccess(
      payload: .init(items: replyItems,
                     device: .init(maxMessages: try wallet.contract.maxMessages, appVersion: keeperVersion))
    )
    return successEvent
  }
  
  // Build connect response with private key provided
  static func buildConnectEventSuccesResponse(requestPayloadItems: [TonConnectRequestPayload.Item],
                                              wallet: Wallet,
                                              keeperVersion: String,
                                              walletPrivateKey: TonSwift.PrivateKey,
                                              manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess {
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
                     device: .init(maxMessages: try wallet.contract.maxMessages, appVersion: keeperVersion))
    )
    return successEvent
  }
  
  static func buildConnectEventSuccesResponse(
    requestPayloadItems: [TonConnectRequestPayload.Item],
    wallet: Wallet,
    keeperVersion: String,
    manifest: TonConnectManifest,
    signTonProof: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply
  ) async throws -> TonConnect.ConnectEventSuccess {
    
    let address = try wallet.address
    var replyItems = [TonConnect.ConnectItemReply]()
    
    for item in requestPayloadItems {
      switch item {
      case .tonAddress:
        let reply = TonConnect.ConnectItemReply.tonAddress(.init(
          address: address,
          network: wallet.identity.network,
          publicKey: try wallet.publicKey,
          walletStateInit: try wallet.stateInit)
        )
        replyItems.append(reply)
        
      case .tonProof(let payload):
        let reply = try await signTonProof(payload)
        replyItems.append(reply)
      case .unknown:
        continue
      }
    }
    
    let successEvent = TonConnect.ConnectEventSuccess(
      payload: .init(items: replyItems, device: .init(maxMessages: try wallet.contract.maxMessages, appVersion: keeperVersion))
    )
    return successEvent
  }

  public static func buildSendTransactionResponseSuccess(
    sessionCrypto: TonConnectSessionCrypto,
    boc: String,
    id: String,
    clientId: String
  ) throws -> String {
    let response = TonConnect.SendResponse.success(
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
  
  public static func buildSignDataResponseSuccess(
    sessionCrypto: TonConnectSessionCrypto,
    signedJSON: String,
    id: String,
    clientId: String
  ) throws -> String {
    let response = TonConnect.SendResponse.success(
      .init(result: signedJSON,
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
    errorCode: TonConnect.SendResponseError.ErrorCode,
    id: String,
    clientId: String
  ) throws -> String {
    let response = TonConnect.SendResponse.error(
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

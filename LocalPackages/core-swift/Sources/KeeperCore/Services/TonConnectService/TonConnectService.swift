import Foundation
import TonConnectAPI
import TonSwift
import BigInt

public enum TonConnectManifestError: Swift.Error {
  case incorrectURL
  case loadFailed(error: Swift.Error)
  case invalidManifest
}

enum TonConnectServiceError: Swift.Error {
  case incorrectUrl
  case manifestLoadFailed
  case unsupportedWalletKind(walletKind: WalletKind)
  case incorrectClientId
}

public protocol TonConnectService {
  func loadAppManifest(parameters: TonConnectParameters) async -> Result<TonConnectManifest, TonConnectManifestError>
  func buildConnectEventSuccessResponse(
    wallet: Wallet,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest, signTonProofHandler:  @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
    keeperVersion: String) async throws -> TonConnect.ConnectEventSuccess
  func encryptSuccessResponse(
    _ successResponse: TonConnect.ConnectEventSuccess,
    parameters: TonConnectParameters,
    sessionCrypto: TonConnectSessionCrypto) throws -> String
  func buildReconnectConnectEventSuccessResponse(
    wallet: Wallet,
    manifest: TonConnectManifest,
    keeperVersion: String) throws -> TonConnect.ConnectEventSuccess
  func storeConnectedApp(wallet: Wallet, sessionCrypto: TonConnectSessionCrypto, parameters: TonConnectParameters, manifest: TonConnectManifest, connectionType: TonConnectApp.ConnectionType) throws
  func confirmConnectionRequest(body: String,
                                sessionCrypto: TonConnectSessionCrypto,
                                parameters: TonConnectParameters) async throws
  func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps
  func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws
  func disconnectApp(_ idx: Int, wallet: Wallet) throws
  func createEmulateRequestBoc(wallet: Wallet,
                              seqno: UInt64,
                              timeout: UInt64,
                              parameters: SendTransactionParam) async throws -> String
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   timeout: UInt64,
                                   parameters: SendTransactionParam,
                                   signClosure: (TransferData) async throws -> String) async throws -> String
  
  func cancelRequest(appRequest: TonConnect.SendTransactionRequest,
                     app: TonConnectApp) async throws
  
  func confirmRequest(boc: String,
                      appRequest: TonConnect.SendTransactionRequest,
                      app: TonConnectApp) async throws
  
  func cancelSignRequest(appRequest: TonConnect.SignDataRequest,
                     app: TonConnectApp) async throws
  
  func confirmSignRequest(signed: SignedDataResult,
                          appRequest: TonConnect.SignDataRequest,
                          app: TonConnectApp) async throws
  
  func getLastEventId() throws -> String
  func saveLastEventId(_ lastEventId: String) throws
  func loadManifest(url: URL) async throws -> TonConnectManifest
}

final class TonConnectServiceImplementation: TonConnectService {
  private let urlSession: URLSession
  private let apiClient: TonConnectAPI.Client
  private let mnemonicsRepository: MnemonicsRepository
  private let tonConnectAppsVault: TonConnectAppsVault
  private let tonConnectRepository: TonConnectRepository
  private let walletBalanceRepository: WalletBalanceRepository
  private let sendService: SendService
  
  init(urlSession: URLSession,
       apiClient: TonConnectAPI.Client,
       mnemonicsRepository: MnemonicsRepository,
       tonConnectAppsVault: TonConnectAppsVault,
       tonConnectRepository: TonConnectRepository,
       walletBalanceRepository: WalletBalanceRepository,
       sendService: SendService
  ) {
    self.urlSession = urlSession
    self.apiClient = apiClient
    self.mnemonicsRepository = mnemonicsRepository
    self.tonConnectAppsVault = tonConnectAppsVault
    self.tonConnectRepository = tonConnectRepository
    self.walletBalanceRepository = walletBalanceRepository
    self.sendService = sendService
  }
  
  func loadAppManifest(parameters: TonConnectParameters) async -> Result<TonConnectManifest, TonConnectManifestError> {
    do {
      let (data, _) = try await urlSession.data(from: parameters.requestPayload.manifestUrl)
      let jsonDecoder = JSONDecoder()
      let manifest = try jsonDecoder.decode(TonConnectManifest.self, from: data)
      guard manifest.url.host?.contains(".") == true else {
        return .failure(.invalidManifest)
      }
      return .success(manifest)
    } catch let decodingError as DecodingError {
      return .failure(.invalidManifest)
    } catch let urlError as URLError {
      if urlError.code == URLError.Code.badURL {
        return .failure(TonConnectManifestError.incorrectURL)
      } else {
        return .failure(TonConnectManifestError.loadFailed(error: urlError))
      }
    } catch {
      return .failure(TonConnectManifestError.loadFailed(error: error))
    }
  }
  
  func buildReconnectConnectEventSuccessResponse(
    wallet: Wallet,
    manifest: TonConnectManifest,
    keeperVersion: String) throws -> TonConnect.ConnectEventSuccess {
      guard wallet.isTonconnectAvailable else {
        throw
          TonConnectServiceError.unsupportedWalletKind(
            walletKind: wallet.identity.kind
          )
      }
      let successResponse = try TonConnectResponseBuilder.buildReconnectConnectEventSuccessResponse(
        wallet: wallet,
        keeperVersion: keeperVersion,
        manifest: manifest
      )
      return successResponse
    }
  
  func buildConnectEventSuccessResponse(
    wallet: Wallet,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest,
    signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply,
    keeperVersion: String) async throws -> TonConnect.ConnectEventSuccess {
      guard wallet.isTonconnectAvailable else {
        throw
          TonConnectServiceError.unsupportedWalletKind(
            walletKind: wallet.identity.kind
          )
      }
      let successResponse = try await TonConnectResponseBuilder
          .buildConnectEventSuccesResponse(
              requestPayloadItems: parameters.requestPayload.items,
              wallet: wallet,
              keeperVersion: keeperVersion,
              manifest: manifest,
              signTonProof: signTonProofHandler
          )
      return successResponse
  }
  
  func encryptSuccessResponse(
    _ successResponse: TonConnect.ConnectEventSuccess,
    parameters: TonConnectParameters,
    sessionCrypto: TonConnectSessionCrypto) throws -> String {
      let responseData = try JSONEncoder().encode(successResponse)
      guard let receiverPublicKey = Data(hex: parameters.clientId) else {
        throw TonConnectServiceError.incorrectClientId
      }
      let response = try sessionCrypto.encrypt(
        message: responseData,
        receiverPublicKey: receiverPublicKey
      )
      let base64Response = response.base64EncodedString()
      return base64Response
    }
  
  func storeConnectedApp(
    wallet: Wallet,
    sessionCrypto: TonConnectSessionCrypto,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest,
    connectionType: TonConnectApp.ConnectionType) throws {
    let tonConnectApp = TonConnectApp(
      clientId: parameters.clientId,
      manifest: manifest,
      keyPair: sessionCrypto.keyPair,
      connectionType: connectionType
    )

    if let apps = try? tonConnectAppsVault.loadValue(key: wallet) {
      try tonConnectAppsVault.saveValue(apps.addApp(tonConnectApp), for: wallet)
    } else {
      let apps = TonConnectApps(apps: [tonConnectApp])
      try tonConnectAppsVault.saveValue(apps.addApp(tonConnectApp), for: wallet)
    }
  }
  
  func confirmConnectionRequest(body: String, 
                                sessionCrypto: TonConnectSessionCrypto,
                                parameters: TonConnectParameters) async throws {
    let resp = try await apiClient.message(
      query: .init(client_id: sessionCrypto.sessionId,
                   to: parameters.clientId, ttl: 300),
      body: .plainText(.init(stringLiteral: body))
    )
    _ = try resp.ok.body.json
  }

  func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps {
    try tonConnectAppsVault.loadValue(key: wallet)
  }
  
  func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws {
    let apps = try getConnectedApps(forWallet: wallet)
    let updatedApps = apps.removeApp(app)
    try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
  }
  
  func disconnectApp(_ idx: Int, wallet: Wallet) throws {
    let apps = try getConnectedApps(forWallet: wallet)
    let updatedApps = apps.removeApp(at: idx)
    try tonConnectAppsVault.saveValue(updatedApps, for: wallet)
  }
  
  func cancelRequest(appRequest: TonConnect.SendTransactionRequest, app: TonConnectApp) async throws {
    let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
    let body = try TonConnectResponseBuilder.buildSendTransactionResponseError(
        sessionCrypto: sessionCrypto,
        errorCode: .userDeclinedAction,
        id: appRequest.id,
        clientId: app.clientId)
    _ = try await apiClient.message(
        query: .init(client_id: sessionCrypto.sessionId,
                     to: app.clientId,
                     ttl: 300),
        body: .plainText(.init(stringLiteral: body))
    )
  }
  
  func confirmSignRequest(signed: SignedDataResult, appRequest: TonConnect.SignDataRequest, app: TonConnectApp) async throws {
    let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
    let body = try TonConnectResponseBuilder
      .buildSignDataResponseSuccess(sessionCrypto: sessionCrypto, signed: signed, id: appRequest.id, clientId: app.clientId)
    
    _ = try await apiClient.message(
        query: .init(client_id: sessionCrypto.sessionId,
                     to: app.clientId,
                     ttl: 300),
        body: .plainText(.init(stringLiteral: body))
    )
  }
  
  func cancelSignRequest(appRequest: TonConnect.SignDataRequest, app: TonConnectApp) async throws {
    let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
    let body = try TonConnectResponseBuilder.buildSendTransactionResponseError(
        sessionCrypto: sessionCrypto,
        errorCode: .userDeclinedAction,
        id: appRequest.id,
        clientId: app.clientId)
    _ = try await apiClient.message(
        query: .init(client_id: sessionCrypto.sessionId,
                     to: app.clientId,
                     ttl: 300),
        body: .plainText(.init(stringLiteral: body))
    )
  }
  
  func confirmRequest(boc: String, appRequest: TonConnect.SendTransactionRequest, app: TonConnectApp) async throws {
    let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
    let body = try TonConnectResponseBuilder
        .buildSendTransactionResponseSuccess(sessionCrypto: sessionCrypto,
                                             boc: boc,
                                             id: appRequest.id,
                                             clientId: app.clientId)
    
    _ = try await apiClient.message(
        query: .init(client_id: sessionCrypto.sessionId,
                     to: app.clientId,
                     ttl: 300),
        body: .plainText(.init(stringLiteral: body))
    )
  }
  
  func createEmulateRequestBoc(wallet: Wallet,
                               seqno: UInt64,
                               timeout: UInt64,
                               parameters: SendTransactionParam) async throws -> String {
    try await createRequestTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: parameters) { transferData in
        let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
          .createUnsignedWalletTransfer(
            wallet: wallet
          )
        let signed = try TransferSigner.signWalletTransfer(
          walletTransfer,
          wallet: wallet,
          seqno: transferData.seqno,
          signer: WalletTransferEmptyKeySigner()
        )
        return try signed.toBoc().hexString()
      }
  }
  
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   timeout: UInt64,
                                   parameters: SendTransactionParam,
                                   signClosure: (TransferData) async throws -> String) async throws -> String {
    return try await createRequestTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: parameters, 
      signClosure: signClosure)
  }
  
  func confirmRequest(wallet: Wallet, appRequestParam: SendTransactionParam) async throws {}
  
  func getLastEventId() throws -> String {
    try tonConnectRepository.getLastEventId().lastEventId
  }
  
  func saveLastEventId(_ lastEventId: String) throws {
    try tonConnectRepository.saveLastEventId(TonConnectLastEventId(lastEventId: lastEventId))
  }
  
  func loadManifest(url: URL) async throws -> TonConnectManifest {
    let (data, _) = try await urlSession.data(from: url)
    let jsonDecoder = JSONDecoder()
    return try jsonDecoder.decode(TonConnectManifest.self, from: data)
  }
}

private extension TonConnectServiceImplementation {
  func rebuildJettonPayloads(wallet: Wallet, messages: [SendTransactionParam.Message]) async throws -> [SendTransactionParam.Message] {
    var rebuildedMessages: [SendTransactionParam.Message] = []
      for message in messages {
        let jettonsBalance = try walletBalanceRepository.getWalletBalance(wallet: wallet).balance.jettonsBalance
        
        let foundJetton = jettonsBalance.first(where: { $0.item.walletAddress == message.address.address })

        guard let jetton = foundJetton else {
          rebuildedMessages.append(message)
          continue
        }
        
        if (jetton.item.jettonInfo.hasCustomPayload == false) {
          rebuildedMessages.append(message)
          continue
        }
        
        let jettonPayload = try await sendService.getJettonCustomPayload(wallet: wallet, jetton: jetton.item.jettonInfo.address)
        
        guard let jettonSendPayload = message.payload else {
          rebuildedMessages.append(message)
          continue
        }
        var jettonTransferData = try JettonTransferData.loadFrom(slice: Cell.fromBase64(src: jettonSendPayload).beginParse())
        
        jettonTransferData.customPayload = jettonPayload.customPayload
        
        rebuildedMessages.append(SendTransactionParam.Message(
          address: message.address,
          amount: message.amount,
          stateInit: try jettonPayload.stateInit != nil ? jettonPayload.stateInit?.toBoc().base64EncodedString() : message.stateInit,
          payload: try Builder().store(jettonTransferData).endCell().toBoc().base64EncodedString()
        ))
      }
    return rebuildedMessages
  }
  
  func createRequestTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   timeout: UInt64,
                                   parameters: SendTransactionParam,
                                   signClosure: (TransferData) async throws -> String) async throws -> String {
    
    let rebuildedMessages = try await rebuildJettonPayloads(wallet: wallet, messages: parameters.messages)
    
    let payloads = rebuildedMessages.map { message in
      TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: message.amount),
        recipientAddress: message.address,
        stateInit: message.stateInit,
        payload: message.payload
      )
    }
    
    let transferData = TransferData(
      transfer: .tonConnect(
        TransferData.TonConnect(
          payloads: payloads,
          sender: parameters.from
        )
      ),
      wallet: wallet,
      messageType: .ext,
      seqno: seqno,
      timeout: timeout
    )
    
    let signed = try await signClosure(transferData)
    return signed
  }
}

import Foundation
import TonConnectAPI
import TonSwift
import BigInt

enum TonConnectServiceError: Swift.Error {
  case incorrectUrl
  case manifestLoadFailed
  case unsupportedWalletKind(walletKind: WalletKind)
  case incorrectClientId
}

public protocol TonConnectService {
  func loadTonConnectConfiguration(with parameters: TonConnectParameters) async throws -> (TonConnectParameters, TonConnectManifest)
  func buildConnectEventSuccessResponse(
    wallet: Wallet,
    passcode: String,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest) async throws -> TonConnect.ConnectEventSuccess
  func encryptSuccessResponse(
    _ successResponse: TonConnect.ConnectEventSuccess,
    parameters: TonConnectParameters,
    sessionCrypto: TonConnectSessionCrypto) throws -> String
  func buildReconnectConnectEventSuccessResponse(
    wallet: Wallet,
    manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess
  func storeConnectedApp(wallet: Wallet, sessionCrypto: TonConnectSessionCrypto, parameters: TonConnectParameters, manifest: TonConnectManifest) throws
  func confirmConnectionRequest(body: String,
                                sessionCrypto: TonConnectSessionCrypto,
                                parameters: TonConnectParameters) async throws
  func getConnectedApps(forWallet wallet: Wallet) throws -> TonConnectApps
  func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws
  func createEmulateRequestBoc(wallet: Wallet,
                              seqno: UInt64,
                              timeout: UInt64,
                              parameters: SendTransactionParam) async throws -> String
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   timeout: UInt64,
                                   parameters: SendTransactionParam,
                                   signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String
  
  func cancelRequest(appRequest: TonConnect.AppRequest,
                     app: TonConnectApp) async throws
  
  func confirmRequest(boc: String,
                      appRequest: TonConnect.AppRequest,
                      app: TonConnectApp) async throws
  
  func getLastEventId() throws -> String
  func saveLastEventId(_ lastEventId: String) throws
  func loadManifest(url: URL) async throws -> TonConnectManifest
  
  func migrateTonConnectAppsVault(wallets: [Wallet])
}

final class TonConnectServiceImplementation: TonConnectService {
  private let urlSession: URLSession
  private let apiClient: TonConnectAPI.Client
  private let mnemonicsRepository: MnemonicsRepository
  private let tonConnectAppsVault: TonConnectAppsVault
  private let tonConnectAppsVaultLegacy: TonConnectAppsVaultLegacy
  private let tonConnectRepository: TonConnectRepository
  private let walletBalanceRepository: WalletBalanceRepository
  private let sendService: SendService
  
  init(urlSession: URLSession,
       apiClient: TonConnectAPI.Client,
       mnemonicsRepository: MnemonicsRepository,
       tonConnectAppsVault: TonConnectAppsVault,
       tonConnectAppsVaultLegacy: TonConnectAppsVaultLegacy,
       tonConnectRepository: TonConnectRepository,
       walletBalanceRepository: WalletBalanceRepository,
       sendService: SendService
  ) {
    self.urlSession = urlSession
    self.apiClient = apiClient
    self.mnemonicsRepository = mnemonicsRepository
    self.tonConnectAppsVault = tonConnectAppsVault
    self.tonConnectAppsVaultLegacy = tonConnectAppsVaultLegacy
    self.tonConnectRepository = tonConnectRepository
    self.walletBalanceRepository = walletBalanceRepository
    self.sendService = sendService
  }
  
  func loadTonConnectConfiguration(with parameters: TonConnectParameters) async throws -> (TonConnectParameters, TonConnectManifest) {
    do {
      let manifest = try await loadManifest(url: parameters.requestPayload.manifestUrl)
      return (parameters, manifest)
    } catch {
      throw TonConnectServiceError.manifestLoadFailed
    }
  }
  
  func buildReconnectConnectEventSuccessResponse(
    wallet: Wallet,
    manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess {
      guard wallet.isTonconnectAvailable else {
        throw
          TonConnectServiceError.unsupportedWalletKind(
            walletKind: wallet.identity.kind
          )
      }
      let successResponse = try TonConnectResponseBuilder.buildReconnectConnectEventSuccessResponse(
        wallet: wallet,
        manifest: manifest
      )
      return successResponse
    }
  
  func buildConnectEventSuccessResponse(
    wallet: Wallet,
    passcode: String,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest) async throws -> TonConnect.ConnectEventSuccess {
      guard wallet.isTonconnectAvailable else {
        throw
          TonConnectServiceError.unsupportedWalletKind(
            walletKind: wallet.identity.kind
          )
      }
      let mnemonic = try await mnemonicsRepository.getMnemonic(wallet: wallet, password: passcode)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      let successResponse = try TonConnectResponseBuilder
          .buildConnectEventSuccesResponse(
              requestPayloadItems: parameters.requestPayload.items,
              wallet: wallet,
              walletPrivateKey: privateKey,
              manifest: manifest
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
    manifest: TonConnectManifest) throws {
    let tonConnectApp = TonConnectApp(
      clientId: parameters.clientId,
      manifest: manifest,
      keyPair: sessionCrypto.keyPair
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
  
  func cancelRequest(appRequest: TonConnect.AppRequest, app: TonConnectApp) async throws {
    let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
    let body = try TonConnectResponseBuilder.buildSendTransactionResponseError(
        sessionCrypto: sessionCrypto,
        errorCode: .userDeclinedTransaction,
        id: appRequest.id,
        clientId: app.clientId)
    _ = try await apiClient.message(
        query: .init(client_id: sessionCrypto.sessionId,
                     to: app.clientId,
                     ttl: 300),
        body: .plainText(.init(stringLiteral: body))
    )
  }
  
  func confirmRequest(boc: String, appRequest: TonConnect.AppRequest, app: TonConnectApp) async throws {
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
      parameters: parameters) { builder in
        try await builder.externalSign(wallet: wallet) { transfer in
          try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
        }
      }
  }
  
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   timeout: UInt64,
                                   parameters: SendTransactionParam,
                                   signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
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
  
  func migrateTonConnectAppsVault(wallets: [Wallet]) {
    let filteredWallets = wallets.filter { $0.isTonconnectAvailable }
    for wallet in filteredWallets {
      guard let apps = try? tonConnectAppsVaultLegacy.loadValue(key: wallet.address.toRaw()) else { continue }
      try? tonConnectAppsVault.saveValue(apps, for: wallet)
    }
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
                                   signClosure: (TransferMessageBuilder) async throws -> String) async throws -> String {
    
    let rebuildedMessages = try await rebuildJettonPayloads(wallet: wallet, messages: parameters.messages)
    
    let payloads = rebuildedMessages.map { message in
      TransferData.TonConnect.Payload(
        value: BigInt(integerLiteral: message.amount),
        recipientAddress: message.address,
        stateInit: message.stateInit,
        payload: message.payload
      )
    }
    
    return try await TransferMessageBuilder(
      transferData: .tonConnect(
        TransferData.TonConnect(
          seqno: seqno,
          payloads: payloads,
          sender: parameters.from,
          timeout: timeout
        )
      )
    ).createBoc(signClosure: signClosure)
  }
}

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
  func loadTonConnectConfiguration(with deeplink: TonConnectDeeplink) async throws -> (TonConnectParameters, TonConnectManifest)
  func buildConnectEventSuccessResponse(
    wallet: Wallet,
    parameters: TonConnectParameters,
    manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess
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
                              parameters: TonConnect.AppRequest.Param) async throws -> String
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   parameters: TonConnect.AppRequest.Param) async throws -> String
  
  func cancelRequest(appRequest: TonConnect.AppRequest,
                     app: TonConnectApp) async throws
  
  func confirmRequest(boc: String,
                      appRequest: TonConnect.AppRequest,
                      app: TonConnectApp) async throws
  
  func getLastEventId() throws -> String
  func saveLastEventId(_ lastEventId: String) throws
  func loadManifest(url: URL) async throws -> TonConnectManifest
}

final class TonConnectServiceImplementation: TonConnectService {
  
  private let urlSession: URLSession
  private let apiClient: TonConnectAPI.Client
  private let mnemonicRepository: WalletMnemonicRepository
  private let tonConnectAppsVault: TonConnectAppsVault
  private let tonConnectRepository: TonConnectRepository
  
  init(urlSession: URLSession,
       apiClient: TonConnectAPI.Client,
       mnemonicRepository: WalletMnemonicRepository,
       tonConnectAppsVault: TonConnectAppsVault,
       tonConnectRepository: TonConnectRepository) {
    self.urlSession = urlSession
    self.apiClient = apiClient
    self.mnemonicRepository = mnemonicRepository
    self.tonConnectAppsVault = tonConnectAppsVault
    self.tonConnectRepository = tonConnectRepository
  }
  
  func loadTonConnectConfiguration(with deeplink: TonConnectDeeplink) async throws -> (TonConnectParameters, TonConnectManifest) {
    let parameters = try parseTonConnectDeeplink(deeplink)
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
      guard wallet.isRegular else { throw
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
    parameters: TonConnectParameters,
    manifest: TonConnectManifest) throws -> TonConnect.ConnectEventSuccess {
      guard wallet.isRegular else { throw
        TonConnectServiceError.unsupportedWalletKind(
          walletKind: wallet.identity.kind
        )
      }
      let mnemonic = try mnemonicRepository.getMnemonic(forWallet: wallet)
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

    let key = try wallet.address.toRaw()
    if let apps = try? tonConnectAppsVault.loadValue(key: key) {
      try tonConnectAppsVault.saveValue(apps.addApp(tonConnectApp), for: key)
    } else {
      let apps = TonConnectApps(apps: [tonConnectApp])
      try tonConnectAppsVault.saveValue(apps.addApp(tonConnectApp), for: key)
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
    try tonConnectAppsVault.loadValue(key: try wallet.address.toRaw())
  }
  
  func disconnectApp(_ app: TonConnectApp, wallet: Wallet) throws {
    let apps = try getConnectedApps(forWallet: wallet)
    let updatedApps = apps.removeApp(app)
    let key = try wallet.address.toRaw()
    try tonConnectAppsVault.saveValue(updatedApps, for: key)
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
                               parameters: TonConnect.AppRequest.Param) async throws -> String {
    try await createRequestTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      parameters: parameters) { transfer in
        try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
  }
  
  func createConfirmTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   parameters: TonConnect.AppRequest.Param) async throws -> String {
    let walletMnemonic = try mnemonicRepository.getMnemonic(forWallet: wallet)
    let keyPair = try Mnemonic.mnemonicToPrivateKey(mnemonicArray: walletMnemonic.mnemonicWords)
    let privateKey = keyPair.privateKey
    return try await createRequestTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      parameters: parameters) { transfer in
        if wallet.isRegular {
            return try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
        }
        // TBD: External wallet sign
        return try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
  }
  
  func confirmRequest(wallet: Wallet, appRequestParam: TonConnect.AppRequest.Param) async throws {
    
  }
  
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
  func createRequestTransactionBoc(wallet: Wallet,
                                   seqno: UInt64,
                                   parameters: TonConnect.AppRequest.Param,
                                   signClosure: (WalletTransfer) async throws -> Data) async throws  -> String{
    let payloads = parameters.messages.map { message in
        TonConnectTransferMessageBuilder.Payload(
            value: BigInt(integerLiteral: message.amount),
            recipientAddress: message.address,
            stateInit: message.stateInit,
            payload: message.payload)
    }
    return try await TonConnectTransferMessageBuilder.sendTonConnectTransfer(
      wallet: wallet,
      seqno: seqno,
      payloads: payloads,
      sender: parameters.from,
      signClosure: signClosure)
  }
  
  func parseTonConnectDeeplink(_ deeplink: TonConnectDeeplink) throws -> TonConnectParameters {
    guard
      let url = URL(string: deeplink.string),
      let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
      components.scheme == .tcScheme,
      let queryItems = components.queryItems,
      let versionValue = queryItems.first(where: { $0.name == .versionKey })?.value,
      let version = TonConnectParameters.Version(rawValue: versionValue),
      let clientId = queryItems.first(where: { $0.name == .clientIdKey })?.value,
      let requestPayloadValue = queryItems.first(where: { $0.name == .requestPayloadKey })?.value,
      let requestPayloadData = requestPayloadValue.data(using: .utf8),
      let requestPayload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: requestPayloadData)
    else {
      throw TonConnectServiceError.incorrectUrl
    }
    
    return TonConnectParameters(
      version: version,
      clientId: clientId,
      requestPayload: requestPayload)
  }
}

private extension String {
  static let tcScheme = "tc"
  static let versionKey = "v"
  static let clientIdKey = "id"
  static let requestPayloadKey = "r"
}

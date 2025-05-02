import Foundation
import TKBatteryAPI
import TonSwift
import BigInt

struct MainnetBatteryAPIHostProvider: APIHostProvider {
  private let configuration: Configuration
  
  init(configuration: Configuration) {
    self.configuration = configuration
  }
  
  var basePath: String {
    get async {
      await configuration.batteryHost(isTestnet: false)
    }
  }
}

struct TestnetBatteryAPIHostProvider: APIHostProvider {
  private let configuration: Configuration
  
  init(configuration: Configuration) {
    self.configuration = configuration
  }
  
  var basePath: String {
    get async {
      await configuration.batteryHost(isTestnet: true)
    }
  }
}

public struct BatteryAPI {
  private let hostProvider: APIHostProvider
  private let urlSession: URLSession
  private let configuration: Configuration
  private let requestCreationQueue: DispatchQueue
  
  init(hostProvider: APIHostProvider,
       urlSession: URLSession,
       configuration: Configuration,
       requestCreationQueue: DispatchQueue) {
    self.hostProvider = hostProvider
    self.urlSession = urlSession
    self.configuration = configuration
    self.requestCreationQueue = requestCreationQueue
  }

  private func createRequest<T>(requestCreation: () -> RequestBuilder<T>) async throws -> RequestBuilder<T> {
    let hostUrl = await hostProvider.basePath
    return requestCreationQueue.sync {
      BatteryAPIAPI.basePath = hostUrl
      let request = requestCreation()
      return request
    }
  }
}

extension BatteryAPI {
  func getBatteryConfig() async throws -> Config {
    let request = try await createRequest {
      return DefaultAPI.getConfigWithRequestBuilder()
    }
    
    let response = try await request.execute().body
    return response
  }
  
  func getBalance(tonProofToken: String) async throws -> BatteryBalance {
    let request = try await createRequest {
      return DefaultAPI.getBalanceWithRequestBuilder(xTonConnectAuth: tonProofToken, units: .ton)
    }
    
    let response = try await request.execute().body
    return try BatteryBalance(balance: response)
  }
  
  func getRechargeMethos(includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod] {
    let request = try await createRequest {
      return DefaultAPI.getRechargeMethodsWithRequestBuilder(includeRechargeOnly: includeRechargeOnly)
    }
    let response = try await request.execute().body
    return response.methods.compactMap { BatteryRechargeMethod(method: $0) }
  }
  
  func emulate(tonProofToken: String, boc: String) async throws -> (responseData: Data, isBatteryAvailable: Bool) {
    let request = try await createRequest {
      return EmulationAPI.emulateMessageToWalletWithRequestBuilder(
        xTonConnectAuth: tonProofToken,
        emulateMessageToWalletRequest: EmulateMessageToWalletRequest(boc: boc)
      )
    }
    let response = try await request.execute()
    let header = response.header
    let isAllowedByBattery = header["allowed-by-battery"] == "true"
    let isSupportedByBattery = header["supported-by-battery"] == "true"
    let isBatteryAvailable = isAllowedByBattery && isSupportedByBattery
    
    let responseData = try JSONEncoder().encode(response.body)

    return (responseData, isBatteryAvailable)
  }
  
  func gasslessEmulate(tonProofToken: String, jettonMasterAddress: String, boc: String) async throws -> String {
    let request = try await createRequest {
      return DefaultAPI.estimateGaslessCostWithRequestBuilder(
        jettonMaster: jettonMasterAddress,
        estimateGaslessCostRequest: EstimateGaslessCostRequest(
          battery: false,
          payload: boc
        ),
        xTonConnectAuth: tonProofToken
      )
    }
    let response = try await request.execute()
    return response.body.commission
  }
  
  func sendMessage(tonProofToken: String, boc: String) async throws {
    let request = try await createRequest {
      return DefaultAPI.sendMessageWithRequestBuilder(
        xTonConnectAuth: tonProofToken,
        emulateMessageToWalletRequest: EmulateMessageToWalletRequest(
          boc: boc
        )
      )
    }
    try await request.execute()
  }
  
  func makePurchase(tonProofToken: String, transactionId: String, promocode: String?) async throws -> IOSBatteryPurchaseStatus {
    let request = try await createRequest {
      return DefaultAPI.iosBatteryPurchaseWithRequestBuilder(
        xTonConnectAuth: tonProofToken,
        iosBatteryPurchaseRequest: IosBatteryPurchaseRequest(
          transactions: [IosBatteryPurchaseRequestTransactionsInner(id: transactionId, promo: promocode)]
        )
      )
    }
    return try await request.execute().body
  }
  
  func verifyPromocode(promocode: String) async throws {
    let request = try await createRequest {
      return DefaultAPI.verifyPurchasePromoWithRequestBuilder(promo: promocode)
    }
    try await request.execute()
  }
  
  func getTronConfig() async throws -> GetTronConfig200Response {
    let request = try await createRequest {
      return DefaultAPI.getTronConfigWithRequestBuilder()
    }
    
    let response = try await request.execute().body
    return response
  }
  
  func getTronEstimate(address: String, energy: Int, bandwidth: Int) async throws -> EstimatedTronTx {
    let request = try await createRequest {
      return DefaultAPI.tronEstimateWithRequestBuilder(wallet: address, energy: energy, bandwidth: bandwidth)
    }
    let response = try await request.execute().body
    return response
  }
  
  func getTronTransactions(tonProofToken: String,
                           limit: Int,
                           maxTimestamp: Int64? = nil) async throws -> [TronTransaction] {
    let request = try await createRequest {
      return DefaultAPI.getTronTransactionsWithRequestBuilder(
        xTonConnectAuth: tonProofToken,
        limit: limit,
        maxTimestamp: maxTimestamp)
    }
    let response = try await request.execute().body
    let transactions = response.transactions.compactMap { try? TronTransaction(apiTransaction: $0) }
    return transactions
  }
  
  func tronSend(tonProofToken: String, wallet: String, tx: String, energy: Int, bandwidth: Int) async throws -> String {
    let request = try await createRequest {
      return DefaultAPI.tronSendWithRequestBuilder(
        xTonConnectAuth: tonProofToken,
        tronSendRequest: TronSendRequest(
          tx: tx,
          energy: energy,
          bandwidth: bandwidth,
          wallet: wallet
        )
      )
    }
    let response = try await request.execute().body
    return response.status
  }
}

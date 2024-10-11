import Foundation
import TKBatteryAPI
import TonSwift
import BigInt

struct MainnetBatteryAPIHostProvider: APIHostProvider {
  private let remoteConfigurationStore: ConfigurationStore
  
  init(remoteConfigurationStore: ConfigurationStore) {
    self.remoteConfigurationStore = remoteConfigurationStore
  }
  
  var basePath: String {
    get async {
      await remoteConfigurationStore.getConfiguration().batteryHost
    }
  }
}

struct TestnetBatteryAPIHostProvider: APIHostProvider {
  private let remoteConfigurationStore: ConfigurationStore
  
  init(remoteConfigurationStore: ConfigurationStore) {
    self.remoteConfigurationStore = remoteConfigurationStore
  }
  
  var basePath: String {
    get async {
      await remoteConfigurationStore.getConfiguration().batteryHost
    }
  }
}

public struct BatteryAPI {
  private let hostProvider: APIHostProvider
  private let urlSession: URLSession
  private let configurationStore: ConfigurationStore
  private let requestBuilderActor: APIRequestBuilderSerialActor
  
  init(hostProvider: APIHostProvider,
       urlSession: URLSession,
       configurationStore: ConfigurationStore,
       requestBuilderActor: APIRequestBuilderSerialActor) {
    self.hostProvider = hostProvider
    self.urlSession = urlSession
    self.configurationStore = configurationStore
    self.requestBuilderActor = requestBuilderActor
  }
  
  private func prepareAPIForRequest() async {
    async let hostUrlTask = await hostProvider.basePath
    let hostURL = await hostUrlTask
    BatteryAPIAPI.basePath = hostURL
  }
}

extension BatteryAPI {
  func loadBatteryConfig() async throws -> Config {
    let request = try await requestBuilderActor.addTask(block: {
      await prepareAPIForRequest()
      return DefaultAPI.getConfigWithRequestBuilder()
    })
    
    let response = try await request.execute().body
    return response
  }
  
  func getBalance(tonProofToken: String) async throws -> BatteryBalance {
    let request = try await requestBuilderActor.addTask(block: {
      await prepareAPIForRequest()
      return DefaultAPI.getBalanceWithRequestBuilder(xTonConnectAuth: tonProofToken, units: .ton)
    })
    
    let response = try await request.execute().body
    return try BatteryBalance(balance: response)
  }
}
//  func getTonConnectProof(address: String,
//                          proof: TonConnect.TonProofItemReplySuccess.Proof) async throws -> String {
//    
//    let signature = try JSONEncoder().encode(proof.signature)
//    let apiProof = TonConnectProofRequestProof(
//      timestamp: Int64(proof.timestamp),
//      domain: TonConnectProofRequestProofDomain(
//        lengthBytes: Int(proof.domain.lengthBytes),
//        value: proof.domain.value
//      ),
//      signature: <#T##String#>,
//      payload: <#T##String#>,
//      stateInit: <#T##String?#>
//    )
//    
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return WalletAPI.tonConnectProofWithRequestBuilder(tonConnectProofRequest: .init(address: address, proof: proof))
//    })
//    
//    let response = try await request.execute().body
//    return response.token
//  }
//  
//  func getBatteryConfig() async throws -> Config {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.getConfigWithRequestBuilder()
//    })
//    
//    let response = try await request.execute().body
//    return response
//  }
//  
//  func getBalance(xTonConnectAuth: String) async throws -> BatteryBalance {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.getBalanceWithRequestBuilder(xTonConnectAuth: xTonConnectAuth, units: .ton)
//    })
//    
//    let response = try await request.execute().body
//    return try BatteryBalance(balance: response)
//  }
//}
//
//// MARK: - Default
//extension BatteryAPIWrapper {
//  func getBalance(xTonConnectAuth: String) async throws -> BatteryBalance {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.getBalanceWithRequestBuilder(xTonConnectAuth: xTonConnectAuth, units: .ton)
//    })
//    
//    let response = try await request.execute().body
//    return try BatteryBalance(balance: response)
//  }
//  
//  func getBatteryConfig() async throws -> Config {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.getConfigWithRequestBuilder()
//    })
//    
//    let response = try await request.execute().body
//    return response
//  }
//  
//  func makePurchase(xTonConnectAuth: String, transactionId: String) async throws -> IOSBatteryPurchaseStatus {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.iosBatteryPurchaseWithRequestBuilder(xTonConnectAuth: xTonConnectAuth, iosBatteryPurchaseRequest: .init(transactions: [.init(id: transactionId)]))
//    })
//    
//    let response = try await request.execute().body
//    
//    return response
//  }
//}
//
//// MARK: - Message
//extension BatteryAPIWrapper {
//  func emulateMessage(xTonConnectAuth: String, boc: String) async throws {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return EmulationAPI.emulateMessageToWalletWithRequestBuilder(xTonConnectAuth: xTonConnectAuth, emulateMessageToWalletRequest: .init(boc: boc))
//    })
//    
//    let response = try await request.execute()
//    // return try BatteryBalance(balance: response)
//  }
//  
//  func sendMessage(xTonConnectAuth: String, boc: String) async throws {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return DefaultAPI.sendMessageWithRequestBuilder(xTonConnectAuth: xTonConnectAuth, emulateMessageToWalletRequest: .init(boc: boc))
//    })
//    
//    let response = try await request.execute()
//  }
//}
//
//
//// MARK: - Wallet
//extension BatteryAPIWrapper {
//  func tonConnectProof(address: String, proof: TonConnectProofRequestProof) async throws -> String {
//    let request = try await requestBuilderActor.addTask(block: {
//      await prepareAPIForRequest()
//      return WalletAPI.tonConnectProofWithRequestBuilder(tonConnectProofRequest: .init(address: address, proof: proof))
//    })
//    
//    let response = try await request.execute().body
//    return response.token
//  }
//}

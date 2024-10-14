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
  func getBatteryConfig() async throws -> Config {
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
  
  func getRechargeMethos(includeRechargeOnly: Bool) async throws -> [BatteryRechargeMethod] {
    let request = try await requestBuilderActor.addTask(block: {
      await prepareAPIForRequest()
      return DefaultAPI.getRechargeMethodsWithRequestBuilder(includeRechargeOnly: includeRechargeOnly)
    })
    let response = try await request.execute().body
    return response.methods.compactMap { BatteryRechargeMethod(method: $0) }
  }
}

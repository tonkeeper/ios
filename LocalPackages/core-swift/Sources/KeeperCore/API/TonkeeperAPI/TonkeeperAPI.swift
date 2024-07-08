import Foundation

enum TonkeeperAPIError: Swift.Error {
  case incorrectUrl
}

protocol TonkeeperAPI {
  func loadConfiguration(lang: String,
                         build: String,
                         chainName: String,
                         platform: String) async throws -> RemoteConfiguration
  func loadChart(period: Period) async throws -> [Coordinate]
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData
  func loadNotifications() async throws -> [InternalNotification]
}

struct TonkeeperAPIImplementation: TonkeeperAPI {
  private let urlSession: URLSession
  private let host: URL
  private let appInfoProvider: AppInfoProvider
  
  init(urlSession: URLSession, host: URL, appInfoProvider: AppInfoProvider) {
    self.urlSession = urlSession
    self.host = host
    self.appInfoProvider = appInfoProvider
  }
  
  func loadConfiguration(lang: String,
                         build: String,
                         chainName: String,
                         platform: String) async throws -> RemoteConfiguration {
    let url = host.appendingPathComponent("/keys")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { throw TonkeeperAPIError.incorrectUrl }
    
    components.queryItems = [
      .init(name: "lang", value: appInfoProvider.language),
      .init(name: "build", value: appInfoProvider.version),
      .init(name: "chainName", value: chainName),
      .init(name: "platform", value: appInfoProvider.platform)
    ]
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(RemoteConfiguration.self, from: data)
    return entity
  }
  
  func loadChart(period: Period) async throws -> [Coordinate] {
    let url = host.appendingPathComponent("/stock/chart-new")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { return [] }
    
    components.queryItems = [
      .init(name: "period", value: period.stringValue)
    ]
    guard let url = components.url else { return [] }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(ChartEntity.self, from: data)
    return entity.coordinates
  }
  
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods {
    let url = host.appendingPathComponent("/fiat/methods")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { throw TonkeeperAPIError.incorrectUrl }
    
    components.queryItems = [
      .init(name: "lang", value: appInfoProvider.language),
      .init(name: "build", value: "5.0.0"),
      .init(name: "chainName", value: "mainnet"),
      .init(name: "platform", value: appInfoProvider.platform)
    ]
    if let countryCode = countryCode {
      components.queryItems?.append(URLQueryItem(name: "countryCode", value: countryCode))
    }
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(FiatMethodsResponse.self, from: data)
    return entity.data
  }
  
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
    let url = host.appendingPathComponent("/apps/popular")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { throw TonkeeperAPIError.incorrectUrl }
    
    components.queryItems = [
      .init(name: "lang", value: appInfoProvider.language),
      .init(name: "build", value: appInfoProvider.version),
      .init(name: "platform", value: appInfoProvider.platform)
    ]
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(PopularAppsResponse.self, from: data)
    return entity.data
  }
  
  func loadNotifications() async throws -> [InternalNotification] {
    let url = host.appendingPathComponent("/notifications")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { throw TonkeeperAPIError.incorrectUrl }
    
    components.queryItems = [
      .init(name: "lang", value: appInfoProvider.language),
      .init(name: "version", value: appInfoProvider.version),
      .init(name: "platform", value: appInfoProvider.platform)
    ]
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let response = try JSONDecoder().decode(InternalNotificationResponse.self, from: data)
    return response.notifications
  }
}

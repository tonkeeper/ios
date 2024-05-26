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
  func loadFiatRates(category: FiatMethodCategory.CategoryType, currency: Currency) async throws -> [FiatMethodRate]
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData
}

struct TonkeeperAPIImplementation: TonkeeperAPI {
  private let urlSession: URLSession
  private let host: URL
  private let bootHost: URL
  
  init(urlSession: URLSession, host: URL, bootHost: URL) {
    self.urlSession = urlSession
    self.host = host
    self.bootHost = bootHost
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
      .init(name: "lang", value: lang),
      .init(name: "build", value: build),
      .init(name: "chainName", value: chainName),
      .init(name: "platform", value: "ios_x")
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
      .init(name: "lang", value: "en"),
      .init(name: "build", value: "3.4.0"),
      .init(name: "chainName", value: "mainnet"),
      .init(name: "platform", value: "ios_x")
    ]
    if let countryCode = countryCode {
      components.queryItems?.append(URLQueryItem(name: "countryCode", value: countryCode))
    }
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(FiatMethodsResponse.self, from: data)
    return entity.data
  }
  
  func loadFiatRates(category: FiatMethodCategory.CategoryType, currency: Currency) async throws -> [FiatMethodRate] {
    let url = bootHost.appendingPathComponent("/widget/\(category.rawValue)/rates")
    guard var components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ) else { throw TonkeeperAPIError.incorrectUrl }
    
    components.queryItems = [
      .init(name: "currency", value: currency.code)
    ]
    guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(FiatMethodsRatesResponse.self, from: data)
    return entity.items
  }
  
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
      let url = host.appendingPathComponent("/apps/popular")
      guard var components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ) else { throw TonkeeperAPIError.incorrectUrl }
      
      components.queryItems = [
        .init(name: "lang", value: lang),
        .init(name: "build", value: "3.4.0"),
        .init(name: "platform", value: "ios_x")
      ]
      guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
      let (data, _) = try await urlSession.data(from: url)
      let entity = try JSONDecoder().decode(PopularAppsResponse.self, from: data)
      return entity.data
    }
}

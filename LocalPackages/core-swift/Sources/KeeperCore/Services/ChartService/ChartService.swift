import Foundation

protocol ChartService {
  func loadChartData(period: Period,
                     token: String,
                     currency: Currency,
                     isTestnet: Bool) async throws -> [Coordinate]
  func getChartData(period: Period,
                    token: String,
                    currency: Currency,
                    isTestnet: Bool) -> [Coordinate]
}

final class ChartServiceImplementation: ChartService {
  private let apiProvider: APIProvider
  private let repository: ChartDataRepository
  
  init(apiProvider: APIProvider,
       repository: ChartDataRepository) {
    self.apiProvider = apiProvider
    self.repository = repository
  }
  
  func loadChartData(period: Period,
                     token: String,
                     currency: Currency,
                     isTestnet: Bool) async throws -> [Coordinate] {
    let coordinates = try await apiProvider.api(isTestnet).getChart(
      token: token,
      period: period,
      currency: currency
    )
    try? repository.saveChartData(
      coordinates: coordinates,
      period: period,
      token: token,
      currency: currency,
      isTestnet: isTestnet
    )
    return coordinates
  }
  
  func getChartData(period: Period,
                    token: String,
                    currency: Currency,
                    isTestnet: Bool) -> [Coordinate] {
    let coordinates = repository.getChartData(
      period: period,
      token: token,
      currency: currency,
      isTestnet: isTestnet
    )
    return coordinates
  }
}


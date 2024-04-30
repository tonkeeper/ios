import Foundation

protocol ChartService {
  func loadChartData(period: Period,
                     token: String,
                     currency: Currency) async throws -> [Coordinate]
  func getChartData(period: Period,
                    token: String,
                    currency: Currency) -> [Coordinate]
}

final class ChartServiceImplementation: ChartService {
  private let api: API
  private let repository: ChartDataRepository
  
  init(api: API,
       repository: ChartDataRepository) {
    self.api = api
    self.repository = repository
  }
  
  func loadChartData(period: Period,
                     token: String,
                     currency: Currency) async throws -> [Coordinate] {
    let coordinates = try await api.getChart(
      token: token,
      period: period,
      currency: currency
    )
    try? repository.saveChartData(
      coordinates: coordinates,
      period: period,
      token: token,
      currency: currency
    )
    return coordinates
  }
  
  func getChartData(period: Period,
                    token: String,
                    currency: Currency) -> [Coordinate] {
    let coordinates = repository.getChartData(
      period: period,
      token: token,
      currency: currency
    )
    return coordinates
  }
}


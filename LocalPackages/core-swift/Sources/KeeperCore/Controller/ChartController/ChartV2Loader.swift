import Foundation

public actor ChartV2Loader {
  
  private var loadChartDataTask: Task<[Coordinate], Error>?
  
  private let chartService: ChartService
  
  init(chartService: ChartService) {
    self.chartService = chartService
  }
  
  public func loadChartData(period: Period,
                            token: String,
                            currency: Currency,
                            isTestnet: Bool) async throws -> [Coordinate] {
    loadChartDataTask?.cancel()
    
    let task = Task {
      let coordinates = try await chartService.loadChartData(
        period: period,
        token: token,
        currency: currency,
        isTestnet: isTestnet
      )
      try Task.checkCancellation()
      return coordinates
    }
    
    loadChartDataTask = task
    return try await task.value
  }
}

import Foundation
import TonSwift
import CoreComponents

protocol ChartDataRepository {
  func getChartData(period: Period, token: String, currency: Currency) -> [Coordinate]
  func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency) throws
}

struct ChartDataRepositoryImplementation: ChartDataRepository {
  let fileSystemVault: FileSystemVault<[Coordinate], String>
  
  init(fileSystemVault: FileSystemVault<[Coordinate], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getChartData(period: Period, token: String, currency: Currency) -> [Coordinate] {
    do {
      return try fileSystemVault.loadItem(key: key(period: period, token: token, currency: currency))
    } catch {
      return []
    }
  }
  
  func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency) throws {
    try fileSystemVault.saveItem(coordinates, key: key(period: period, token: token, currency: currency))
  }
  
  private func key(period: Period, token: String, currency: Currency) -> String {
    return "\(period.stringValue)_\(currency.code)_\(token)"
  }
}

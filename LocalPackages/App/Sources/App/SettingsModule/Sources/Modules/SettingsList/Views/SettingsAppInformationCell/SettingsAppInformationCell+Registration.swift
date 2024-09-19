import UIKit

typealias SettingsAppInformationCellRegistration = UICollectionView.CellRegistration<SettingsAppInformationCell, SettingsAppInformationCell.Configuration>
extension SettingsAppInformationCellRegistration {
  static var registration: SettingsAppInformationCellRegistration {
    SettingsAppInformationCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
    }
  }
}

import UIKit

typealias NotificationBannerCellRegistration = UICollectionView.CellRegistration<NotificationBannerCell, NotificationBannerCell.Configuration>
extension NotificationBannerCellRegistration {
  static var registration: NotificationBannerCellRegistration {
    NotificationBannerCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
    }
  }
}

import UIKit

typealias NotificationBannerCellRegistration = UICollectionView.CellRegistration<NotificationBannerCell, NotificationBannerCell.Configuration>
extension NotificationBannerCellRegistration {
    static var registration: NotificationBannerCellRegistration {
        NotificationBannerCellRegistration { cell, _, configuration in
            cell.configuration = configuration
        }
    }
}

import UIKit

typealias SettingsListSectionHeaderViewRegistration = UICollectionView.SupplementaryRegistration<SettingsListSectionHeaderView>
extension SettingsListSectionHeaderViewRegistration {
  static func registration() -> SettingsListSectionHeaderViewRegistration {
    SettingsListSectionHeaderViewRegistration(elementKind: SettingsListSectionHeaderView.elementKind) { _, _, _ in }
  }
}

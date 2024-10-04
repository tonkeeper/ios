import UIKit

typealias SettingsListSectionFooterViewRegistration = UICollectionView.SupplementaryRegistration<SettingsListSectionFooterView>
extension SettingsListSectionFooterViewRegistration {
  static func registration() -> SettingsListSectionFooterViewRegistration {
    SettingsListSectionFooterViewRegistration(elementKind: SettingsListSectionFooterView.elementKind) { _, _, _ in }
  }
}

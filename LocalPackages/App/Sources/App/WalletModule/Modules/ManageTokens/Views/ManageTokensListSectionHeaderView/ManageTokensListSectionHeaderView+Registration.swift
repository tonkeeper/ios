import UIKit

typealias ManageTokensListSectionHeaderViewRegistration = UICollectionView.SupplementaryRegistration<ManageTokensListSectionHeaderView>
extension ManageTokensListSectionHeaderViewRegistration {
  static func registration() -> ManageTokensListSectionHeaderViewRegistration {
    ManageTokensListSectionHeaderViewRegistration(elementKind: ManageTokensListSectionHeaderView.elementKind) { _, _, _ in }
  }
}

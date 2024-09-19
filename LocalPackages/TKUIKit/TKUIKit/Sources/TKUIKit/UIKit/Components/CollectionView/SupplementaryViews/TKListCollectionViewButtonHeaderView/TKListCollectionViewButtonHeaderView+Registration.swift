import UIKit

public typealias TKListCollectionViewButtonHeaderViewRegistration = UICollectionView.SupplementaryRegistration<TKListCollectionViewButtonHeaderView>
public extension TKListCollectionViewButtonHeaderViewRegistration {
  static func registration() -> TKListCollectionViewButtonHeaderViewRegistration {
    TKListCollectionViewButtonHeaderViewRegistration(elementKind: TKListCollectionViewButtonHeaderView.elementKind) { _, _, _ in }
  }
}

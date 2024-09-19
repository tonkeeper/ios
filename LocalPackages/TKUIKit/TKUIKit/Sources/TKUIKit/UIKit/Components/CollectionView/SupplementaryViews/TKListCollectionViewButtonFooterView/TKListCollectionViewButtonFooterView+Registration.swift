import UIKit

public typealias TKListCollectionViewButtonFooterViewRegistration = UICollectionView.SupplementaryRegistration<TKListCollectionViewButtonFooterView>
public extension TKListCollectionViewButtonFooterViewRegistration {
  static func registration() -> TKListCollectionViewButtonFooterViewRegistration {
    TKListCollectionViewButtonFooterViewRegistration(elementKind: TKListCollectionViewButtonFooterView.elementKind) { _, _, _ in }
  }
}

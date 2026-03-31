import UIKit

public typealias TKButtonCollectionViewCellRegistration = UICollectionView.CellRegistration<TKButtonCollectionViewCell, TKButtonCollectionViewCell.Configuration>
public extension TKButtonCollectionViewCellRegistration {
    static func registration() -> TKButtonCollectionViewCellRegistration {
        TKButtonCollectionViewCellRegistration { cell, _, configuration in
            cell.configuration = configuration
        }
    }
}

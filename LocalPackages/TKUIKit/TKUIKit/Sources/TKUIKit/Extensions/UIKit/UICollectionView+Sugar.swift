import UIKit.UICollectionView

public extension UICollectionView {
    func registerHeaderViewClass(_ viewClass: AnyClass) {
        register(
            viewClass,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: String(describing: viewClass) + ".Header"
        )
    }

    func dequeueReusableHeaderView<T: UICollectionReusableView>(for indexPath: IndexPath) -> T {
        guard let view = dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: String(describing: T.self) + ".Header",
            for: indexPath
        ) as? T else {
            fatalError("Unable to dequeue reusable header for indexPath: \((indexPath.section, indexPath.item))")
        }
        return view
    }
}

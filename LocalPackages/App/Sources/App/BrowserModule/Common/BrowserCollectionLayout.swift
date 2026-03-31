import UIKit

enum BrowserCollectionLayout {
    static func appsSectionLayout(
        hasSectionTitle: Bool,
        twoLinesAppsTitle: Bool
    ) -> NSCollectionLayoutSection {
        let itemHeight: NSCollectionLayoutDimension
        if twoLinesAppsTitle {
            itemHeight = .estimated(104)
        } else {
            itemHeight = .absolute(104)
        }
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / 4),
            heightDimension: itemHeight
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(104)
        )
        let group: NSCollectionLayoutGroup
        if #available(iOS 16.0, *) {
            group = NSCollectionLayoutGroup.horizontalGroup(
                with: groupSize,
                repeatingSubitem: item,
                count: 4
            )
        } else {
            group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitem: item,
                count: 4
            )
        }
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 12, bottom: 16, trailing: 12)

        if hasSectionTitle {
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(56)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: BrowserExploreSectionHeaderView.reuseIdentifier,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
        }

        return section
    }
}

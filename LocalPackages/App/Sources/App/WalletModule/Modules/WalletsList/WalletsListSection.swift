import TKUIKit
import UIKit

enum WalletsListSection: Hashable {
    case raffleBanner(raffleId: String)
    case wallets(footerConfiguration: TKListCollectionViewButtonFooterView.Configuration)
}

struct WalletsListItem: Hashable, Equatable {
    let identifier: String
    let accessories: [TKListItemAccessory]
    let selectAccessories: [TKListItemAccessory]
    let editingAccessories: [TKListItemAccessory]
    let onSelection: (() -> Void)?

    static func == (lhs: WalletsListItem, rhs: WalletsListItem) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    init(
        identifier: String,
        accessories: [TKListItemAccessory],
        selectAccessories: [TKListItemAccessory],
        editingAccessories: [TKListItemAccessory],
        onSelection: (() -> Void)? = nil
    ) {
        self.identifier = identifier
        self.accessories = accessories
        self.selectAccessories = selectAccessories
        self.editingAccessories = editingAccessories
        self.onSelection = onSelection
    }

    private static let raffleBannerIdentifierPrefix = "raffleBanner-"

    static func raffleBannerItem(raffleId: String) -> WalletsListItem {
        WalletsListItem(
            identifier: raffleBannerIdentifierPrefix + raffleId,
            accessories: [],
            selectAccessories: [],
            editingAccessories: []
        )
    }

    /// Edit-mode reorder is wallet-only; the banner row isn't designed to participate.
    var isRaffleBanner: Bool {
        identifier.hasPrefix(Self.raffleBannerIdentifierPrefix)
    }
}

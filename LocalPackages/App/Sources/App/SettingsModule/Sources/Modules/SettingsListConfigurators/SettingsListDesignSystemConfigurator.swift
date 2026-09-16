import TKUIKit

final class SettingsListDesignSystemConfigurator: SettingsListConfigurator {
    var didSelectCellsCatalog: (() -> Void)?
    var didSelectTransactionCellPreviews: (() -> Void)?
    var didSelectNFTCardPreviews: (() -> Void)?
    var didSelectIconButtonViewPreviews: (() -> Void)?
    var didSelectWalletButtonPreviews: (() -> Void)?
    var didSelectBatterySwiftUIViewPreviews: (() -> Void)?
    var didSelectNotificationBannerPreviews: (() -> Void)?
    var didSelectButtonViewPreviews: (() -> Void)?
    var didSelectModalCardHeaderPreviews: (() -> Void)?
    var didSelectListTitleViewPreviews: (() -> Void)?
    var didSelectTabCategoriesViewPreviews: (() -> Void)?
    var didSelectPlaceholderViewPreviews: (() -> Void)?
    var didSelectChartPreviews: (() -> Void)?
    var didSelectCircularLoaderPreviews: (() -> Void)?
    var didSelectColorsPreviews: (() -> Void)?
    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        "Design System"
    }

    func getInitialState() -> SettingsListState {
        SettingsListState(
            sections: [
                .items(
                    SettingsListItemsSection(
                        items: [
                            .listItem(createCellsCatalogItem()),
                            .listItem(createTransactionCellPreviewsItem()),
                            .listItem(createNFTCardPreviewsItem()),
                            .listItem(createButtonViewPreviewsItem()),
                            .listItem(createIconButtonViewPreviewsItem()),
                            .listItem(createWalletButtonPreviewsItem()),
                            .listItem(createBatterySwiftUIViewPreviewsItem()),
                            .listItem(createNotificationBannerPreviewsItem()),
                            .listItem(createModalCardHeaderPreviewsItem()),
                            .listItem(createListTitleViewPreviewsItem()),
                            .listItem(createTabCategoriesViewPreviewsItem()),
                            .listItem(createPlaceholderViewPreviewsItem()),
                            .listItem(createChartPreviewsItem()),
                            .listItem(createCircularLoaderPreviewsItem()),
                            .listItem(createColorsPreviewsItem()),
                        ],
                        header: SettingsListSectionHeader(
                            title: "Components"
                        )
                    )
                ),
            ]
        )
    }

    private func createCellsCatalogItem() -> SettingsListItem {
        createNavigationItem(
            title: "Cells",
            id: .designSystemCellsCatalogItemIdentifier
        ) { [weak self] in
            self?.didSelectCellsCatalog?()
        }
    }

    private func createTransactionCellPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Transaction Cell",
            id: .designSystemTransactionCellPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectTransactionCellPreviews?()
        }
    }

    private func createNFTCardPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "NFT Card",
            id: .designSystemNFTCardPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectNFTCardPreviews?()
        }
    }

    private func createButtonViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Button View",
            id: .designSystemButtonViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectButtonViewPreviews?()
        }
    }

    private func createIconButtonViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Icon Button View",
            id: .designSystemIconButtonViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectIconButtonViewPreviews?()
        }
    }

    private func createWalletButtonPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Wallet Button",
            id: .designSystemWalletButtonPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectWalletButtonPreviews?()
        }
    }

    private func createBatterySwiftUIViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Battery SwiftUI View",
            id: .designSystemBatterySwiftUIViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectBatterySwiftUIViewPreviews?()
        }
    }

    private func createNotificationBannerPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Notification Banner",
            id: .designSystemNotificationBannerPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectNotificationBannerPreviews?()
        }
    }

    private func createModalCardHeaderPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Modal Card Header",
            id: .designSystemModalCardHeaderPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectModalCardHeaderPreviews?()
        }
    }

    private func createListTitleViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "List Title View",
            id: .designSystemListTitleViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectListTitleViewPreviews?()
        }
    }

    private func createTabCategoriesViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Tab Categories View",
            id: .designSystemTabCategoriesViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectTabCategoriesViewPreviews?()
        }
    }

    private func createPlaceholderViewPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Placeholder View",
            id: .designSystemPlaceholderViewPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectPlaceholderViewPreviews?()
        }
    }

    private func createChartPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Chart",
            id: .designSystemChartPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectChartPreviews?()
        }
    }

    private func createCircularLoaderPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Circular Loader",
            id: .designSystemCircularLoaderPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectCircularLoaderPreviews?()
        }
    }

    private func createColorsPreviewsItem() -> SettingsListItem {
        createNavigationItem(
            title: "Colors",
            id: .designSystemColorsPreviewsItemIdentifier
        ) { [weak self] in
            self?.didSelectColorsPreviews?()
        }
    }

    private func createNavigationItem(
        title: String,
        id: String,
        onSelection: @escaping () -> Void
    ) -> SettingsListItem {
        SettingsListItem(
            id: id,
            title: SettingsListItemTitle(title),
            accessory: .chevron,
            onTap: { _ in
                onSelection()
            }
        )
    }
}

private extension String {
    static let designSystemCellsCatalogItemIdentifier = "designSystemCellsCatalogItemIdentifier"
    static let designSystemTransactionCellPreviewsItemIdentifier = "designSystemTransactionCellPreviewsItemIdentifier"
    static let designSystemNFTCardPreviewsItemIdentifier = "designSystemNFTCardPreviewsItemIdentifier"
    static let designSystemIconButtonViewPreviewsItemIdentifier = "designSystemIconButtonViewPreviewsItemIdentifier"
    static let designSystemWalletButtonPreviewsItemIdentifier = "designSystemWalletButtonPreviewsItemIdentifier"
    static let designSystemBatterySwiftUIViewPreviewsItemIdentifier = "designSystemBatterySwiftUIViewPreviewsItemIdentifier"
    static let designSystemNotificationBannerPreviewsItemIdentifier = "designSystemNotificationBannerPreviewsItemIdentifier"
    static let designSystemButtonViewPreviewsItemIdentifier = "designSystemButtonViewPreviewsItemIdentifier"
    static let designSystemModalCardHeaderPreviewsItemIdentifier = "designSystemModalCardHeaderPreviewsItemIdentifier"
    static let designSystemListTitleViewPreviewsItemIdentifier = "designSystemListTitleViewPreviewsItemIdentifier"
    static let designSystemTabCategoriesViewPreviewsItemIdentifier = "designSystemTabCategoriesViewPreviewsItemIdentifier"
    static let designSystemPlaceholderViewPreviewsItemIdentifier = "designSystemPlaceholderViewPreviewsItemIdentifier"
    static let designSystemChartPreviewsItemIdentifier = "designSystemChartPreviewsItemIdentifier"
    static let designSystemCircularLoaderPreviewsItemIdentifier = "designSystemCircularLoaderPreviewsItemIdentifier"
    static let designSystemColorsPreviewsItemIdentifier = "designSystemColorsPreviewsItemIdentifier"
}

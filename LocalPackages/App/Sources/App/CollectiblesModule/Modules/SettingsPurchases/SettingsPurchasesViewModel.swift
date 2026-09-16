import AppUI
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

enum SettingsPurchasesSection: Hashable {
    case visible
    case hidden
    case spam

    var id: String {
        switch self {
        case .visible:
            "visible"
        case .hidden:
            "hidden"
        case .spam:
            "spam"
        }
    }

    var title: String {
        switch self {
        case .visible:
            TKLocales.Settings.Purchases.Sections.visible
        case .hidden:
            TKLocales.Settings.Purchases.Sections.hidden
        case .spam:
            TKLocales.Settings.Purchases.Sections.spam
        }
    }
}

protocol SettingsPurchasesModuleOutput: AnyObject {
    var didOpenTonviewer: ((URL) -> Void)? { get set }
}

protocol SettingsPurchasesViewModel: AnyObject {
    var didUpdateState: ((SettingsPurchasesScreenState) -> Void)? { get set }

    func viewDidLoad()
}

final class SettingsPurchasesViewModelImplementation: SettingsPurchasesViewModel, SettingsPurchasesModuleOutput {
    private struct ItemData {
        let title: String
        let subtitle: String
        let imageURL: URL?
    }

    private enum SectionState {
        case collapsed
        case expanded
    }

    private enum ItemState {
        case visible
        case hidden
        case spam
    }

    var didOpenTonviewer: ((URL) -> Void)?

    var didUpdateState: ((SettingsPurchasesScreenState) -> Void)?

    func viewDidLoad() {
        model.didUpdate = { [weak self] event in
            DispatchQueue.main.async {
                switch event {
                case let .didUpdateItems(state), let .didUpdateManagementState(state):
                    self?.update(state: state)
                }
            }
        }
        update(state: model.state)
    }

    private var sectionStates = [SettingsPurchasesSection: SectionState]()
    private var detailsPresentation: PurchasesManagementDetailsPresentation?

    private let model: SettingsPurchasesModel
    private let mode: SettingsPurchasesMode
    private let wallet: Wallet
    private let tonviewerURLBuilder: TonviewerURLBuilder

    init(
        model: SettingsPurchasesModel,
        mode: SettingsPurchasesMode,
        wallet: Wallet,
        tonviewerURLBuilder: TonviewerURLBuilder
    ) {
        self.model = model
        self.mode = mode
        self.wallet = wallet
        self.tonviewerURLBuilder = tonviewerURLBuilder
    }
}

private extension SettingsPurchasesViewModelImplementation {
    func update(state: SettingsPurchasesModel.State) {
        didUpdateState?(
            SettingsPurchasesScreenState(
                title: title,
                sections: createSections(state),
                details: detailsPresentation,
                onDismissDetails: { [weak self] in
                    self?.hideDetails()
                }
            )
        )
    }

    func hideDetails() {
        guard detailsPresentation != nil else { return }
        detailsPresentation = nil
        update(state: model.state)
    }

    var title: String {
        switch mode {
        case .spam:
            TKLocales.Collectibles.spamButton
        case .all:
            TKLocales.Collectibles.title
        }
    }

    func createSections(_ state: SettingsPurchasesModel.State) -> [SettingsPurchasesScreenState.Section] {
        var sections = [SettingsPurchasesScreenState.Section]()

        switch mode {
        case .all:
            if !state.visible.isEmpty {
                sections.append(
                    createSection(
                        section: .visible,
                        items: state.visible,
                        itemState: .visible,
                        state: state
                    )
                )
            }

            if !state.hidden.isEmpty {
                sections.append(
                    createSection(
                        section: .hidden,
                        items: state.hidden,
                        itemState: .hidden,
                        state: state
                    )
                )
            }
        case .spam:
            break
        }

        let hasSpam = !state.spam.isEmpty || state.blacklistedCount > 0
        if hasSpam {
            var spamItems = createItems(
                items: state.spam,
                section: .spam,
                itemState: .spam,
                state: state
            )
            if state.blacklistedCount > 0 {
                spamItems.append(createAllSpamItem(state: state))
            }
            sections.append(
                SettingsPurchasesScreenState.Section(
                    id: SettingsPurchasesSection.spam.id,
                    title: SettingsPurchasesSection.spam.title,
                    items: spamItems,
                    showAllButton: createShowAllButtonIfNeeded(items: state.spam, section: .spam)
                )
            )
        }

        return sections
    }

    private func createSection(
        section: SettingsPurchasesSection,
        items: [SettingsPurchasesModel.Item],
        itemState: ItemState,
        state: SettingsPurchasesModel.State
    ) -> SettingsPurchasesScreenState.Section {
        SettingsPurchasesScreenState.Section(
            id: section.id,
            title: section.title,
            items: createItems(
                items: items,
                section: section,
                itemState: itemState,
                state: state
            ),
            showAllButton: createShowAllButtonIfNeeded(items: items, section: section)
        )
    }

    private func createItems(
        items: [SettingsPurchasesModel.Item],
        section: SettingsPurchasesSection,
        itemState: ItemState,
        state: SettingsPurchasesModel.State
    ) -> [SettingsPurchasesScreenState.Item] {
        collapsedItemsIfNeeded(items: items, section: section)
            .map { item in
                createItem(
                    item: item,
                    itemState: itemState,
                    state: state
                )
            }
    }

    func collapsedItemsIfNeeded(
        items: [SettingsPurchasesModel.Item],
        section: SettingsPurchasesSection
    ) -> [SettingsPurchasesModel.Item] {
        guard items.count > Constants.collapsedItemsCount,
              sectionStates[section] != .expanded
        else {
            return items
        }
        return Array(items.prefix(Constants.collapsedItemsCount))
    }

    func createShowAllButtonIfNeeded(
        items: [SettingsPurchasesModel.Item],
        section: SettingsPurchasesSection
    ) -> SettingsPurchasesScreenState.ShowAllButton? {
        guard items.count > Constants.collapsedItemsCount,
              sectionStates[section] != .expanded
        else {
            return nil
        }
        return SettingsPurchasesScreenState.ShowAllButton(
            title: TKLocales.List.showAll,
            action: { [weak self] in
                guard let self else { return }
                sectionStates[section] = .expanded
                update(state: model.state)
            }
        )
    }

    private func createItem(
        item: SettingsPurchasesModel.Item,
        itemState: ItemState,
        state: SettingsPurchasesModel.State
    ) -> SettingsPurchasesScreenState.Item {
        let itemData = createItemData(item: item, collectionNfts: state.collectionNfts)
        return SettingsPurchasesScreenState.Item(
            id: item.id,
            image: .url(itemData.imageURL),
            title: itemData.title,
            subtitle: itemData.subtitle,
            control: createControl(item: item, itemState: itemState),
            showsChevron: itemState == .spam,
            action: { [weak self] in
                guard let self else { return }
                detailsPresentation = PurchasesManagementDetailsPresentation(
                    id: item.id,
                    state: createDetailsState(
                        item: item,
                        collectionNfts: state.collectionNfts,
                        itemState: itemState
                    )
                )
                update(state: model.state)
            }
        )
    }

    private func createControl(
        item: SettingsPurchasesModel.Item,
        itemState: ItemState
    ) -> SettingsPurchasesScreenState.Item.Control? {
        switch itemState {
        case .visible:
            SettingsPurchasesScreenState.Item.Control(
                kind: .hide,
                action: { [model] in
                    model.hideItem(item)
                }
            )
        case .hidden:
            SettingsPurchasesScreenState.Item.Control(
                kind: .show,
                action: { [model] in
                    model.showItem(item)
                }
            )
        case .spam:
            nil
        }
    }

    func createAllSpamItem(
        state: SettingsPurchasesModel.State
    ) -> SettingsPurchasesScreenState.Item {
        SettingsPurchasesScreenState.Item(
            id: Constants.allSpamItemIdentifier,
            image: .icon(.TKUIKit.Icons.Size44.exclamationMark),
            title: "All spam",
            subtitle: "\(state.blacklistedCount) \(TKLocales.Settings.Purchases.Token.tokenCount(count: state.blacklistedCount))",
            showsChevron: true,
            action: { [weak self, tonviewerURLBuilder, wallet] in
                do {
                    guard let url = try tonviewerURLBuilder.buildURL(
                        context: .accountCollectibles(address: wallet.address),
                        network: wallet.network
                    ) else {
                        return
                    }
                    self?.didOpenTonviewer?(url)
                } catch {
                    Log.w("SettingsPurchases: failed to build all spam tonviewer url, error: \(error)")
                }
            }
        )
    }

    private func createItemData(
        item: SettingsPurchasesModel.Item,
        collectionNfts: [NFTCollection: [NFT]]
    ) -> ItemData {
        let title: String
        let subtitle: String
        let imageURL: URL?
        switch item {
        case let .collection(collection):
            title = collection.notEmptyName ?? TKLocales.Settings.Purchases.Token.unnamedCollection
            let nftsCount = collectionNfts[collection]?.count ?? 0
            subtitle = "\(nftsCount) \(TKLocales.Settings.Purchases.Token.tokenCount(count: nftsCount))"
            imageURL = collectionNfts[collection]?.first?.preview.size500
        case let .single(nft):
            title = nft.name ?? nft.address.toShortString(bounceable: true)
            subtitle = TKLocales.Settings.Purchases.Token.singleToken
            imageURL = nft.preview.size500
        }
        return ItemData(
            title: title,
            subtitle: subtitle,
            imageURL: imageURL
        )
    }

    private func createDetailsState(
        item: SettingsPurchasesModel.Item,
        collectionNfts: [NFTCollection: [NFT]],
        itemState: ItemState
    ) -> PurchasesManagementDetailsViewState {
        let title: String
        let items: [PurchasesManagementDetailsViewState.Item]

        switch item {
        case let .single(nft):
            title = TKLocales.Settings.Purchases.Details.Title.singleToken
            items = [
                PurchasesManagementDetailsViewState.Item(
                    id: Constants.tokenIdItemIdentifier,
                    title: TKLocales.Settings.Purchases.Details.Items.tokenId,
                    value: nft.address.toShortString(bounceable: true),
                    accessory: .copy,
                    copyValue: nft.address.toString(bounceable: true)
                ),
            ]
        case let .collection(collection):
            title = TKLocales.Settings.Purchases.Details.Title.collection
            items = [
                PurchasesManagementDetailsViewState.Item(
                    id: Constants.nameItemIdentifier,
                    title: TKLocales.Settings.Purchases.Details.Items.name,
                    value: collection.notEmptyName ?? TKLocales.Settings.Purchases.Token.unnamedCollection,
                    accessory: .image(collectionNfts[collection]?.first?.preview.size500)
                ),
                PurchasesManagementDetailsViewState.Item(
                    id: Constants.collectionIdItemIdentifier,
                    title: TKLocales.Settings.Purchases.Details.Items.collectionId,
                    value: collection.address.toShortString(bounceable: true),
                    accessory: .copy,
                    copyValue: collection.address.toString(bounceable: true)
                ),
            ]
        }

        return PurchasesManagementDetailsViewState(
            title: title,
            items: items,
            button: PurchasesManagementDetailsViewState.Button(
                title: createDetailsButtonTitle(item: item, itemState: itemState),
                action: { [weak self] in
                    guard let self else { return }
                    switch itemState {
                    case .visible:
                        model.hideItem(item)
                    case .hidden, .spam:
                        model.showItem(item)
                    }
                    hideDetails()
                }
            )
        )
    }

    private func createDetailsButtonTitle(
        item: SettingsPurchasesModel.Item,
        itemState: ItemState
    ) -> String {
        switch item {
        case .single:
            switch itemState {
            case .visible:
                TKLocales.Settings.Purchases.Details.Button.hideToken
            case .hidden:
                TKLocales.Settings.Purchases.Details.Button.showToken
            case .spam:
                model.isMarkedAsSpam(item: item)
                    ? TKLocales.Settings.Purchases.Details.Button.notSpam
                    : TKLocales.Settings.Purchases.Details.Button.showToken
            }
        case .collection:
            switch itemState {
            case .visible:
                TKLocales.Settings.Purchases.Details.Button.hideCollection
            case .hidden:
                TKLocales.Settings.Purchases.Details.Button.showCollection
            case .spam:
                model.isMarkedAsSpam(item: item)
                    ? TKLocales.Settings.Purchases.Details.Button.notSpam
                    : TKLocales.Settings.Purchases.Details.Button.showCollection
            }
        }
    }
}

private enum Constants {
    static let collapsedItemsCount: Int = 4
    static let allSpamItemIdentifier: String = "allSpamItemIdentifier"
    static let tokenIdItemIdentifier: String = "tokenId"
    static let nameItemIdentifier: String = "name"
    static let collectionIdItemIdentifier: String = "collectionId"
}

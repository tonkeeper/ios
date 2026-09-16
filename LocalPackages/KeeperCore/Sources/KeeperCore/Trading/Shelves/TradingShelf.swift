import Foundation
import TKTradingAPI

public struct TradingShelfGrid: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var source: String
    public var seeAllCategory: TradingAssetCategory?
    public var initialCatalogSearchSort: MultichainAssetSearchSort
    public var items: [TradingMarketItem]

    init?(config: Components.Schemas.ShelfConfig) {
        let items = (config.items ?? []).compactMap(TradingMarketItem.init(item:))
        guard !items.isEmpty else {
            return nil
        }
        self.init(
            id: config.key.rawValue,
            name: config.title,
            source: config.source,
            seeAllCategory: config.see_all.enabled
                ? TradingAssetCategory(tradingApiValue: config.see_all.route)
                : nil,
            initialCatalogSearchSort: Self.initialCatalogSearchSort(for: config.key),
            items: items
        )
    }

    init(
        id: String,
        name: String,
        source: String,
        seeAllCategory: TradingAssetCategory?,
        initialCatalogSearchSort: MultichainAssetSearchSort = .marketCap,
        items: [TradingMarketItem]
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.seeAllCategory = seeAllCategory
        self.initialCatalogSearchSort = initialCatalogSearchSort
        self.items = items
    }

    private static func initialCatalogSearchSort(
        for key: Components.Schemas.MarketListKey
    ) -> MultichainAssetSearchSort {
        switch key {
        case .market_cap:
            .marketCap
        case .volume:
            .volume
        case .top_gainers:
            .priceDiffDesc
        case .top_losers:
            .priceDiffAsc
        default:
            .marketCap
        }
    }
}

public struct TradingShelf: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var groups: [TradingShelfGroup]

    public init(
        id: String,
        title: String,
        groups: [TradingShelfGroup]
    ) {
        self.id = id
        self.title = title
        self.groups = groups
    }

    public init(
        id: String,
        title: String,
        grids: [TradingShelfGrid]
    ) {
        self.init(
            id: id,
            title: title,
            groups: [
                TradingShelfGroup(
                    id: id,
                    title: title,
                    grids: grids
                ),
            ]
        )
    }
}

public struct TradingShelfGroup: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var grids: [TradingShelfGrid]

    public init(
        id: String,
        title: String,
        grids: [TradingShelfGrid]
    ) {
        self.id = id
        self.title = title
        self.grids = grids
    }
}

extension TradingShelf {
    init?(shelf: Components.Schemas.ShelfGroup) {
        guard let group = TradingShelfGroup(shelf: shelf) else {
            return nil
        }
        self.init(
            id: Self.stableID(for: shelf),
            title: shelf.name,
            groups: [group]
        )
    }

    init?(multichainShelf: Components.Schemas.MultichainShelfGroup) {
        let groups = multichainShelf.groups.compactMap(TradingShelfGroup.init(shelf:))
        guard !groups.isEmpty else {
            return nil
        }
        self.init(
            id: multichainShelf.id,
            title: multichainShelf.name,
            groups: groups
        )
    }

    private static func stableID(for shelf: Components.Schemas.ShelfGroup) -> String {
        TradingShelfGroup.stableID(for: shelf)
    }
}

extension TradingShelfGroup {
    init?(shelf: Components.Schemas.ShelfGroup) {
        let grids = shelf.items.compactMap(TradingShelfGrid.init(config:))
        guard !grids.isEmpty else {
            return nil
        }
        self.init(
            id: Self.stableID(for: shelf),
            title: shelf.name,
            grids: grids
        )
    }

    fileprivate static func stableID(for shelf: Components.Schemas.ShelfGroup) -> String {
        let gridIDs = shelf.items.map(\.key.rawValue).joined(separator: "|")
        return "\(shelf.name)|\(gridIDs)"
    }
}

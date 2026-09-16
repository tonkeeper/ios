import KeeperCore

enum TradeShelvesMapper {
    static func makeShelves(
        from snapshot: TradingShelvesSnapshot,
        itemsMapper: TradeItemsMapper
    ) -> [TradeShelfViewData] {
        snapshot.shelves.map { shelf in
            TradeShelfViewData(
                id: shelf.id,
                title: shelf.title,
                groups: shelf.groups.map { group in
                    TradeShelfGroupViewData(
                        id: group.id,
                        title: group.title,
                        grids: group.grids.map { grid in
                            TradeShelfGridViewData(
                                id: grid.id,
                                name: grid.name,
                                items: grid.items.map(itemsMapper.assetViewData),
                                seeAllCategory: grid.seeAllCategory,
                                initialCatalogSearchSort: grid.initialCatalogSearchSort
                            )
                        }
                    )
                }
            )
        }
    }

    static func applyingMarketItems(
        _ marketItems: [String: TradingMarketItem],
        to shelves: [TradeShelfViewData],
        itemsMapper: TradeItemsMapper
    ) -> [TradeShelfViewData] {
        shelves.map { shelf in
            var shelf = shelf
            shelf.groups = shelf.groups.map { group in
                var group = group
                group.grids = group.grids.map { grid in
                    var grid = grid
                    grid.items = grid.items.map { view in
                        guard let item = marketItems[view.id] else { return view }
                        return itemsMapper.applyingChange(
                            to: view,
                            change24hPercent: item.change24hPercent,
                            isUnverified: item.isUnverified,
                            isTrusted: item.isTrusted
                        )
                    }
                    return grid
                }
                return group
            }
            return shelf
        }
    }
}

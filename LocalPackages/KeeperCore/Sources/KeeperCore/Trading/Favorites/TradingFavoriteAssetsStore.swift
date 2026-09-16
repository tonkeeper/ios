import Foundation

struct TradingFavoriteAssetsStore: Codable, Equatable {
    struct Item: Codable, Equatable {
        var id: String
        var symbol: String?
        var imageURLString: String?
        var addedAt: Date

        init(
            id: String,
            addedAt: Date
        ) {
            self.id = id
            self.addedAt = addedAt
        }

        var asset: TradingFavoriteAsset {
            TradingFavoriteAsset(
                id: id,
                symbol: nonEmpty(symbol) ?? id,
                imageURL: imageURLString.flatMap(URL.init(string:)),
                addedAt: addedAt
            )
        }

        mutating func apply(_ context: TradingFavoriteAssetContext) {
            if let symbol = nonEmpty(context.symbol) {
                self.symbol = symbol
            }
            if let imageURL = context.imageURL {
                self.imageURLString = imageURL.absoluteString
            }
        }

        func nonEmpty(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                return nil
            }
            return value
        }
    }

    var items: [String: Item]

    init(items: [String: Item] = [:]) {
        self.items = items
    }
}

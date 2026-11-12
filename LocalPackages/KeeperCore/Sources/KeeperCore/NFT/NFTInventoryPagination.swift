import Foundation

enum NFTInventoryPaginationError: Error {
    case nonProgressingPage
}

func loadCompleteNFTInventory<Item>(
    identity: (Item) -> String,
    fetchPage: (Int, Int) async throws -> [Item]
) async throws -> [Item] {
    var items = [Item]()
    var seen = Set<String>()
    var offset = 0
    while true {
        try Task.checkCancellation()
        let page = try await fetchPage(1000, offset)
        try Task.checkCancellation()
        if page.isEmpty {
            return items
        }
        let previousCount = seen.count
        for item in page where seen.insert(identity(item)).inserted {
            items.append(item)
        }
        guard seen.count > previousCount else {
            throw NFTInventoryPaginationError.nonProgressingPage
        }
        // Advance by raw response size, before deduplication or lossy NFT mapping.
        offset += page.count
    }
}

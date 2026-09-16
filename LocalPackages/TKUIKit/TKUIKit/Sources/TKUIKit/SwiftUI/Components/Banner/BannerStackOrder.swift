struct BannerStackOrder: Equatable {
    private(set) var itemIDs: [String]

    var currentID: String? {
        itemIDs.last
    }

    var previousID: String? {
        itemIDs[safe: itemIDs.count - 2]
    }

    var previousPreviousID: String? {
        itemIDs[safe: itemIDs.count - 3]
    }

    func presentationPreviousPreviousID(isSwipePresentationActive: Bool) -> String? {
        if let previousPreviousID {
            return previousPreviousID
        }

        guard itemIDs.count == 2,
              isSwipePresentationActive
        else {
            return nil
        }

        return currentID
    }

    var count: Int {
        itemIDs.count
    }

    var canCycleCurrentItem: Bool {
        itemIDs.count > 1
    }

    mutating func moveCurrentToBottom() {
        guard canCycleCurrentItem,
              let currentID = itemIDs.popLast()
        else {
            return
        }

        itemIDs.insert(currentID, at: 0)
    }

    mutating func remove(id: String) {
        itemIDs.removeAll { $0 == id }
    }

    mutating func sync(with externalItemIDs: [String]) {
        let externalItemIDSet = Set(externalItemIDs)
        itemIDs.removeAll { !externalItemIDSet.contains($0) }

        for itemID in externalItemIDs where !itemIDs.contains(itemID) {
            itemIDs.append(itemID)
        }
    }
}

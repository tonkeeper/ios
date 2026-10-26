import KeeperCore

enum MultichainHistoryEventTarget {
    static func activity(
        eventId: String,
        in activities: [MultichainActivity]
    ) -> MultichainActivity? {
        let eventId = eventId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventId.isEmpty else {
            return nil
        }

        if let exact = activities.first(where: { activity in
            activity.txIds.contains { matches($0, eventId) }
        }) {
            return exact
        }

        guard let parsed = indexedTransactionID(eventId) else {
            return nil
        }
        let candidates = activities.filter { activity in
            activity.txIds.contains { matches($0, parsed.txId) }
        }
        guard parsed.index < candidates.count else {
            return nil
        }
        return candidates[parsed.index]
    }

    /// The newest activity carrying one of the hashes, whatever chain prefix or event index its id has.
    static func activity(
        transactionHashes: Set<String>,
        in activities: [MultichainActivity]
    ) -> MultichainActivity? {
        let hashes = Set(transactionHashes.map(normalizedHash)).subtracting([""])
        guard !hashes.isEmpty else {
            return nil
        }
        return activities.first { activity in
            activity.txIds.contains { hashes.contains(transactionHash($0)) }
        }
    }

    /// The listed version of an activity already on screen. A settled row can come back under
    /// another chain prefix or with other fields filled in, so a lone row sharing its transaction
    /// hash stands in for it too.
    static func current(
        of activity: MultichainActivity,
        in activities: [MultichainActivity]
    ) -> MultichainActivity? {
        let identity = MultichainHistoryActivityIdentity(activity: activity)
        if let same = activities.first(where: { MultichainHistoryActivityIdentity(activity: $0) == identity }) {
            return same
        }
        let hashes = Set(activity.txIds.map(transactionHash)).subtracting([""])
        let candidates = activities.filter { candidate in
            candidate.txIds.contains { hashes.contains(transactionHash($0)) }
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}

private extension MultichainHistoryEventTarget {
    static func transactionHash(_ txId: String) -> String {
        let parts = txId.split(separator: ":", omittingEmptySubsequences: false)
        return normalizedHash(String(parts.count > 1 ? parts[1] : parts[0]))
    }

    static func indexedTransactionID(_ eventId: String) -> (txId: String, index: Int)? {
        guard let separator = eventId.lastIndex(of: ":") else {
            return nil
        }
        let suffix = eventId[eventId.index(after: separator)...]
        guard !suffix.isEmpty,
              suffix.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let index = Int(suffix)
        else {
            return nil
        }
        let txId = String(eventId[..<separator])
        guard txId.contains(":") else {
            return nil
        }
        return (txId, index)
    }

    static func normalizedHash(_ hash: String) -> String {
        let value = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }

    static func matches(_ txId: String, _ expected: String) -> Bool {
        txId.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(expected) == .orderedSame
    }
}

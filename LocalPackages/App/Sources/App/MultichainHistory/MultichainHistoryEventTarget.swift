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
        let hashes = Set(activity.txIds.map(transactionHash)).subtracting([""])
        if hashes.isEmpty, activity.status == .pending,
           [.perpsBalanceDeposit, .perpsBalanceWithdrawal].contains(activity.activityType)
        {
            return listedFunding(of: activity, in: activities)
        }
        let identity = MultichainHistoryActivityIdentity(activity: activity)
        if let same = activities.first(where: { MultichainHistoryActivityIdentity(activity: $0) == identity }) {
            return same
        }
        guard !hashes.isEmpty else {
            return nil
        }
        let candidates = activities.filter { candidate in
            candidate.txIds.contains { hashes.contains(transactionHash($0)) }
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// A Perps deposit or withdrawal is listed pending before it has a transaction, and its time stays
    /// when it settles. A withdrawal then gets its hashes and destination chain; a deposit keeps no hashes,
    /// and its amount turns from the quoted one into the credited one. Pending operations of one shape
    /// differ only in time, which the identity leaves out, so the time decides here.
    private static func listedFunding(
        of activity: MultichainActivity,
        in activities: [MultichainActivity]
    ) -> MultichainActivity? {
        let candidates = activities.filter { candidate in
            candidate.activityType == activity.activityType
                && candidate.direction == activity.direction
                && candidate.blockTime == activity.blockTime
                && candidate.walletAddress?.lowercased() == activity.walletAddress?.lowercased()
                && candidate.outToken?.assetId == activity.outToken?.assetId
                && (activity.activityType == .perpsBalanceDeposit
                    ? candidate.inToken?.assetId == activity.inToken?.assetId
                    : candidate.outAmount == activity.outAmount)
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}

extension MultichainHistoryEventTarget {
    /// The history lists `<chain>:<hash>`, while the app keeps the bare hash; both give the same key.
    static func transactionHash(_ txId: String) -> String {
        let parts = txId.split(separator: ":", omittingEmptySubsequences: false)
        return normalizedHash(String(parts.count > 1 ? parts[1] : parts[0]))
    }
}

private extension MultichainHistoryEventTarget {
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

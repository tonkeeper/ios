import Foundation

public struct TokenManagementState: Codable {
    public let pinnedItems: [String]
    public let unpinnedItems: [String]
    public let hiddenState: [String: Bool]
}

extension TokenManagementState {
    /// The native coin is pinned unless the user unpinned it; states persisted before it became
    /// manageable mention it in neither list.
    func pinningNativeCoinByDefault() -> TokenManagementState {
        let nativeCoin = TonInfo.symbol
        guard !pinnedItems.contains(nativeCoin), !unpinnedItems.contains(nativeCoin) else {
            return self
        }
        return TokenManagementState(
            pinnedItems: [nativeCoin] + pinnedItems,
            unpinnedItems: unpinnedItems,
            hiddenState: hiddenState
        )
    }
}

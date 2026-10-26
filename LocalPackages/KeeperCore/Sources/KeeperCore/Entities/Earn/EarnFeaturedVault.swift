import Foundation

public struct EarnFeaturedVault: Equatable, Sendable, Encodable {
    public let network: String
    public let vaultId: String

    public init?(network: String, vaultId: String) {
        let network = network.trimmingCharacters(in: .whitespacesAndNewlines)
        let vaultId = vaultId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !network.isEmpty, Self.isVaultId(vaultId) else {
            return nil
        }
        self.network = network
        self.vaultId = vaultId
    }

    private static func isVaultId(_ vaultId: String) -> Bool {
        let parts = vaultId.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let head = parts.first else { return false }
        return head.isEVMAddress && (parts.count == 1 || !parts[1].isEmpty)
    }
}

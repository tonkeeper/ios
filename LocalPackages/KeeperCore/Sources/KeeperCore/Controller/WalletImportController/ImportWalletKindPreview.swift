import Foundation

public enum ImportWalletKind: String, Equatable, Hashable, Sendable {
    case ton
    case multichain
}

public enum ImportWalletKindPreference: Equatable, Sendable {
    case automatic
    case selected(ImportWalletKind)
}

public struct ImportWalletKindPreview: Equatable, Sendable {
    public let fiatTotal: Decimal
    public let nftsCount: Int
    public let hasActivity: Bool

    public init(
        fiatTotal: Decimal,
        nftsCount: Int,
        hasActivity: Bool? = nil
    ) {
        self.fiatTotal = fiatTotal
        self.nftsCount = nftsCount
        self.hasActivity = hasActivity ?? (fiatTotal > 0 || nftsCount > 0)
    }

    public static let empty = ImportWalletKindPreview(fiatTotal: 0, nftsCount: 0)
}

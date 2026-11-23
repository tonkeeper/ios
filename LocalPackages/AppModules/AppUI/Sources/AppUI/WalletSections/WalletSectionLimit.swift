public enum WalletSectionLimit: Int, CaseIterable, Identifiable, Sendable {
    case top3 = 3
    case top10 = 10
    case top25 = 25

    public static let initial = WalletSectionLimit.top3

    public var id: Int {
        rawValue
    }

    public var count: Int {
        rawValue
    }
}

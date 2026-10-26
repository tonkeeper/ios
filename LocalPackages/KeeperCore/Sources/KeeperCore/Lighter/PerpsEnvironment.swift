/// The two environment scopes perps values are keyed by. They are different strings on
/// purpose and neither is free to rename.
enum PerpsEnvironment {
    /// The venue. A funding operation records it and recovery filters on it, so an
    /// operation written under another spelling is invisible to recovery rather than
    /// rejected. Nonce and execution lanes are scoped by the same value.
    static let venue = "mainnet"

    /// The on-device storage scope: the journal file name and the keychain entry derive
    /// from it, so changing it orphans the operations and credentials a wallet already has.
    static let storage = "production"
}

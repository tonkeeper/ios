/// What the coordinator may do with WalletConnect right now.
///
/// A deeplink starts a pairing for the wallet the user is looking at, so it depends on the
/// active wallet. An incoming event belongs to a session that already names its own wallet and
/// has to keep working whichever wallet is active — the per-item wallet checks happen where the
/// proposal or request is presented.
struct WalletConnectAvailability: Equatable {
    enum DeeplinkDecision: Equatable {
        case pair
        case activeWalletNotMultichain
    }

    let isActiveWalletMultichain: Bool

    var deeplinkDecision: DeeplinkDecision {
        guard isActiveWalletMultichain else {
            return .activeWalletNotMultichain
        }
        return .pair
    }
}

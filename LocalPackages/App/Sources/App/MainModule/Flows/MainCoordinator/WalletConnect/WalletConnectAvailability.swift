/// What the coordinator may do with WalletConnect right now.
///
/// The two decisions have deliberately different scopes. A deeplink starts a pairing for the
/// wallet the user is looking at, so it depends on the active wallet. An incoming event belongs
/// to a session that already names its own wallet and has to keep working whichever wallet is
/// active, so it depends only on the feature being available — the per-item wallet checks happen
/// where the proposal or request is presented.
struct WalletConnectAvailability: Equatable {
    enum DeeplinkDecision: Equatable {
        case pair
        case featureUnavailable
        case activeWalletNotMultichain
    }

    let isMultichainEnabled: Bool
    let isActiveWalletMultichain: Bool

    var canHandleEvents: Bool {
        isMultichainEnabled
    }

    var deeplinkDecision: DeeplinkDecision {
        guard isMultichainEnabled else {
            return .featureUnavailable
        }
        guard isActiveWalletMultichain else {
            return .activeWalletNotMultichain
        }
        return .pair
    }
}

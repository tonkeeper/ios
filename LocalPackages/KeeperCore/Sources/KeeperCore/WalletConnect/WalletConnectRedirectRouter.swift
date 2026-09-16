import Foundation
import ReownRouter

public enum WalletConnectRedirectRouter {
    public enum RoutingPolicy: Equatable {
        case qr
        case browser
        case nativeDapp
        case deeplink

        public init(source: DappConnectionSource?) {
            switch source {
            case .qr:
                self = .qr
            case .browser:
                self = .browser
            case .dapp,
                 .deeplink,
                 .none:
                self = .deeplink
            }
        }
    }

    public static func nativeRedirectURI(
        for dapp: WalletConnectDapp,
        source: DappConnectionSource?
    ) -> String? {
        guard RoutingPolicy(source: source) == .nativeDapp,
              let uri = validatedNativeRedirectURI(dapp.redirect?.native)
        else {
            return nil
        }
        return uri
    }

    @MainActor
    public static func goBackIfNeeded(
        to dapp: WalletConnectDapp,
        source: DappConnectionSource?
    ) {
        guard let uri = nativeRedirectURI(for: dapp, source: source) else {
            return
        }
        ReownRouter.goBack(uri: uri)
    }
}

private extension WalletConnectRedirectRouter {
    static func validatedNativeRedirectURI(_ rawURI: String?) -> String? {
        guard let uri = rawURI?.trimmingCharacters(in: .whitespacesAndNewlines),
              !uri.isEmpty,
              let components = URLComponents(string: uri),
              let scheme = components.scheme?.lowercased(),
              !scheme.isEmpty,
              !selfLoopSchemes.contains(scheme),
              !webSchemes.contains(scheme)
        else {
            return nil
        }
        return uri
    }

    static var selfLoopSchemes: Set<String> {
        [
            "tc",
            "ton",
            "tonkeeper",
            "tonkeeper-mob",
            "tonkeeper-tc",
            "tonkeeper-tc-mob",
            "wc",
        ]
    }

    static var webSchemes: Set<String> {
        ["http", "https"]
    }
}

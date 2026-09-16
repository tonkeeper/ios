import KeeperCore
import TKLocalize
import TKUIKit

enum MultichainAssetListVerificationStatus: Equatable {
    case scam
    case unverified

    init?(details: MultichainAssetDetails) {
        guard !details.isVerified else { return nil }
        switch details.verification {
        case .blacklist:
            self = .scam
        case .none:
            self = .unverified
        case .trusted, .whitelist:
            return nil
        }
    }

    var subtitle: String {
        switch self {
        case .scam:
            TKLocales.Token.scam
        case .unverified:
            TKLocales.Token.unverified
        }
    }

    var subtitleColor: TKColor {
        switch self {
        case .scam:
            .accentRed
        case .unverified:
            .accentOrange
        }
    }
}

import Foundation
import TonSwift

/// User-specified status for the asset.
enum AssetUserPolicy: Codable {
    /// Asset is not sorted explicitly by the user
    case Undecided
    /// Asset is approved by the user
    case Approved
    /// Asset is declined by the user
    case Declined
}

/// Specifies whitelisted/blacklisted tokens, issuers, collections.
struct AssetsPolicy: Codable, Equatable {
    /// Policies for each token address (minter / collection / issuer)
    var policies: [TonSwift.Address: AssetUserPolicy]

    /// Ordered contract addresses. Declined are added in the end, accepted are moved to the top.
    var ordered: [TonSwift.Address]
}

import Foundation
import TonSwift

/// External provider's policy for the asset.
enum AssetExternalPolicy {
  /// Asset does not have a clear publicly known status
  case Unknown
  /// Asset is whitelisted by external provider
  case Whitelisted
  /// Asset is marked as spam/scam
  case Blacklisted
}

/// User-specified status for the asset.
enum AssetUserPolicy: Codable {
  /// Asset is not sorted explicitly by the user
  case Undecided
  /// Asset is approved by the user
  case Approved
  /// Asset is declined by the user
  case Declined
}

/// Resulting policy for the item
enum AssetResolvedPolicy {
  /// Asset is pending user's choice
  case Pending
  /// Asset is enabled (either whitelisted or approved by user)
  case Enabled
  /// Asset is disabled (either blacklisted or explicitly declined by user)
  case Disabled
  
  /// Returns policy for the asset given two policies: external and the user's.
  static func resolve(externalPolicy: AssetExternalPolicy, userPolicy: AssetUserPolicy) -> Self {
    switch userPolicy {
    case .Approved: return .Enabled
    case .Declined: return .Disabled
    case .Undecided:
      switch externalPolicy {
      case .Unknown: return .Pending
      case .Whitelisted: return .Enabled
      case .Blacklisted: return .Disabled
      }
    }
  }
}

/// Specifies whitelisted/blacklisted tokens, issuers, collections.
struct AssetsPolicy: Codable, Equatable {
  /// Policies for each token address (minter / collection / issuer)
  var policies: [TonSwift.Address: AssetUserPolicy]
  
  /// Ordered contract addresses. Declined are added in the end, accepted are moved to the top.
  var ordered: [TonSwift.Address]
}



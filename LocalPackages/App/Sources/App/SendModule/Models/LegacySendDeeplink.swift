import BigInt
import KeeperCore
import TonSwift
import TronSwift

/// A transfer deeplink's `asset_id` expressed the way the TON-only send flow consumes it. Assets
/// out of that flow's reach have no case here.
enum LegacySendDeeplinkAsset: Equatable {
    case ton
    case jetton(TonSwift.Address)
    case tronUSDT

    init?(assetId: String) {
        guard let components = AssetIdComponents(assetId: assetId),
              let chain = MultichainChain(assetIdChain: components.chain)
        else {
            return nil
        }
        switch (chain, components) {
        case let (.ton, .coin(_, _, coin)) where coin == "coin":
            self = .ton
        case let (.ton, .asset(_, _, type, address)) where type == "jetton":
            guard let jettonAddress = try? TonSwift.Address.parse(address) else {
                return nil
            }
            self = .jetton(jettonAddress)
        case let (.tron, .asset(_, _, type, address))
            where type == "trc20" && address == TronSwift.USDT.address.base58:
            self = .tronUSDT
        default:
            return nil
        }
    }

    var chain: MultichainChain {
        switch self {
        case .ton, .jetton:
            .ton
        case .tronUSDT:
            .tron
        }
    }

    var jettonAddress: TonSwift.Address? {
        switch self {
        case let .jetton(address):
            address
        case .ton, .tronUSDT:
            nil
        }
    }
}

/// What a transfer deeplink sends on a wallet without multichain send.
///
/// `asset_id` is only a hint here: one link is meant to serve both wallet kinds, so it can name a
/// multichain asset and pair it with a `jetton` fallback. An asset this flow cannot reach is
/// therefore dropped rather than failing the link — and the amount is dropped with it, being
/// denominated in the asset that was named, not in the fallback.
struct LegacySendDeeplinkPlan: Equatable {
    let jettonAddress: TonSwift.Address?
    let amount: BigUInt?

    init(
        assetId: String?,
        jettonAddress: TonSwift.Address?,
        amount: BigUInt?,
        recipientChain: MultichainChain
    ) {
        let pinnedAsset = assetId.flatMap(LegacySendDeeplinkAsset.init(assetId:))

        if pinnedAsset?.chain == recipientChain {
            self.jettonAddress = pinnedAsset?.jettonAddress
            self.amount = amount
        } else {
            self.jettonAddress = jettonAddress
            self.amount = assetId == nil ? amount : nil
        }
    }
}

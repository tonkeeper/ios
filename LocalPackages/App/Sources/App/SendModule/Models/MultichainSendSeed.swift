import BigInt
import KeeperCore
import TonSwift
import TronSwift

struct MultichainSendSeed {
    let assetId: String
    let amount: BigUInt
}

extension SendInput {
    func multichainSeed() -> MultichainSendSeed? {
        switch self {
        case let .direct(item):
            return item.multichainSeed()
        case .withdraw:
            return nil
        }
    }
}

private extension SendV3Item {
    func multichainSeed() -> MultichainSendSeed? {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(token, amount):
                return MultichainSendSeed(
                    assetId: token.multichainAssetId,
                    amount: amount
                )
            case .nft:
                return nil
            }
        case let .tron(item):
            return MultichainSendSeed(
                assetId: KeeperCore.Token.tron(item.token).assetId(network: .mainnet),
                amount: item.amount
            )
        }
    }
}

private extension TonToken {
    var multichainAssetId: String {
        switch self {
        case .ton:
            return "ton/mainnet/coin"
        case let .jetton(jettonItem):
            return "ton/mainnet/jetton/\(jettonItem.jettonInfo.address.toRaw())"
        }
    }
}

import BigInt
import Foundation
import TonSwift
import TronSwift

public extension ProcessedBalance {
    func amount(for asset: OnRampLayoutToken) -> BigUInt? {
        if asset.isTronNetwork {
            return amountForTronLayoutAsset(asset)
        }

        if asset.symbol.uppercased() == TonInfo.symbol.uppercased() {
            return BigUInt(tonItem.amount)
        }

        guard let addressString = asset.address, let address = try? Address.parse(addressString) else {
            return nil
        }

        let probe = JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: address,
            fractionDigits: asset.decimals,
            name: asset.symbol,
            symbol: asset.symbol,
            verification: .none,
            imageURL: nil
        )

        return getBalanceForJetton(probe)?.amount
    }

    private func amountForTronLayoutAsset(_ asset: OnRampLayoutToken) -> BigUInt? {
        if asset.address == USDT.address.base58 {
            return tronUSDTItem?.amount ?? 0
        } else {
            return nil
        }
    }
}

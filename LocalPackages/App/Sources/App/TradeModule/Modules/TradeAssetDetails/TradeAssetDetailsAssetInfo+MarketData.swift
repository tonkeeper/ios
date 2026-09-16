import Foundation
import KeeperCore
import TonSwift
import TronSwift

enum TradingAssetToken {
    case ton
    case jetton(TonSwift.Address)
    case tronUsdt(TronSwift.Address)
    case tronTrx

    init?(assetId: String) {
        guard let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }
        let normalizedChain: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let isTonChain: (String) -> Bool = {
            normalizedChain($0) == "ton"
        }
        let isTronChain: (String) -> Bool = {
            normalizedChain($0) == "tron"
        }
        let normalizedAddress: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch components {
        case let .coin(chain, _, _):
            if isTonChain(chain) {
                self = .ton
            } else if isTronChain(chain) {
                self = .tronTrx
            } else {
                return nil
            }
        case let .asset(chain, _, _, address):
            if isTonChain(chain) {
                guard
                    let address = try? AnyAddress(rawAddress: normalizedAddress(address)).address
                else {
                    return nil
                }
                self = .jetton(address)
            } else if isTronChain(chain), normalizedAddress(TronSwift.USDT.address.base58) == normalizedAddress(address) {
                self = .tronUsdt(TronSwift.USDT.address)
            } else {
                return nil
            }
        }
    }
}

extension TradingAssetInfo {
    var typedAssetId: TradingAssetToken? {
        TradingAssetToken(assetId: assetId)
    }
}

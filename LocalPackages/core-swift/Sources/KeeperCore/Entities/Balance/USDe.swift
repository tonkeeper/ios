import Foundation
import TonSwift

public enum USDe {
    public static let address = JettonMasterAddress.USDe
    public static let fractionDigits: Int = 6
    public static let symbol = "USDe"
    public static let name = "USDe"
}

public enum StakedUSDe {
    public static let address = JettonMasterAddress.tsUSDe
    public static let fractionDigits: Int = 6
    public static let symbol = "USDe"
    public static let name = "Staked USDe"
}

public extension JettonItem {
    static var usde: JettonItem {
        JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.USDe,
                fractionDigits: USDe.fractionDigits,
                name: USDe.name,
                symbol: USDe.symbol,
                verification: .whitelist,
                imageURL: nil
            ),
            walletAddress: nil
        )
    }

    static var stakedUsde: JettonItem {
        JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.tsUSDe,
                fractionDigits: StakedUSDe.fractionDigits,
                name: StakedUSDe.name,
                symbol: StakedUSDe.symbol,
                verification: .whitelist,
                imageURL: nil
            ),
            walletAddress: nil
        )
    }
}

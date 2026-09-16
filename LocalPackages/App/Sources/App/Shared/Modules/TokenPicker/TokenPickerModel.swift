import BigInt
import Foundation
import KeeperCore
import TKUIKit
import TonSwift
import TronSwift
import UIKit

struct TokenPickerModelState {
    let wallet: Wallet
    let tonBalance: ConvertedTonBalance?
    let jettonBalances: [ConvertedJettonBalance]
    let tronUSDTBalance: ConvertedBalanceTronUSDTItem?
    let tronTRXBalance: ConvertedBalanceTronTRXItem?
    let selectedToken: PickerToken
    let scrollToSelected: Bool
    let mode: PickerMode

    enum PickerToken: Equatable {
        case ton(TonToken)
        case tron(TronToken)
    }

    enum PickerMode {
        case balance(showConverted: Bool, currency: Currency? = nil)
        case name
    }

    struct TronRow {
        let token: TronToken
        let name: String
        let symbol: String
        let image: UIImage
        let network: TokenPicker.Network?
        let identifier: String
        let amount: BigUInt
        let converted: Decimal

        var pickerToken: PickerToken {
            .tron(token)
        }
    }

    var tronRows: [TronRow] {
        var rows = [TronRow]()
        if let tronUSDTBalance {
            rows.append(
                TronRow(
                    token: .usdt,
                    name: TronSwift.USDT.name,
                    symbol: TronSwift.USDT.symbol,
                    image: .TKUIKit.Icons.Size44.currencyUsdt,
                    network: .trc20,
                    identifier: TronSwift.USDT.address.base58,
                    amount: tronUSDTBalance.amount,
                    converted: tronUSDTBalance.converted
                )
            )
        }
        if let tronTRXBalance {
            rows.append(
                TronRow(
                    token: .trx,
                    name: TronSwift.TRX.name,
                    symbol: TronSwift.TRX.symbol,
                    image: .TKUIKit.Icons.Size44.trxChain,
                    network: nil,
                    identifier: TronSwift.TRX.symbol,
                    amount: tronTRXBalance.amount,
                    converted: tronTRXBalance.converted
                )
            )
        }
        return rows
    }
}

protocol TokenPickerModel: AnyObject {
    var didUpdateState: ((TokenPickerModelState?) -> Void)? { get set }

    func getState() -> TokenPickerModelState?
}

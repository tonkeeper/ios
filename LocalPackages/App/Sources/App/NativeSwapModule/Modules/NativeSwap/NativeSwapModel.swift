import BigInt
import Foundation
import KeeperCore

struct NativeSwapModel {
    struct ScaleableAmount {
        var UIAmount: BigUInt
        var amount: BigUInt
    }

    var fromToken: KeeperCore.Token
    var toToken: KeeperCore.Token
    var fromAmount: ScaleableAmount {
        didSet {
            guard oldValue.UIAmount != fromAmount.UIAmount || oldValue.amount != fromAmount.amount else { return }

            if fromAmount.UIAmount != oldValue.UIAmount {
                fromAmount.amount = Self.convertUIToRaw(fromAmount.UIAmount, token: fromToken)
            } else if fromAmount.amount != oldValue.amount {
                fromAmount.UIAmount = Self.convertRawToUI(fromAmount.amount, token: fromToken)
            }
        }
    }

    var toAmount: ScaleableAmount {
        didSet {
            guard oldValue.UIAmount != toAmount.UIAmount || oldValue.amount != toAmount.amount else { return }

            if toAmount.UIAmount != oldValue.UIAmount {
                toAmount.amount = Self.convertUIToRaw(toAmount.UIAmount, token: toToken)
            } else if toAmount.amount != oldValue.amount {
                toAmount.UIAmount = Self.convertRawToUI(toAmount.amount, token: toToken)
            }
        }
    }

    func swap() -> Self {
        NativeSwapModel(
            fromToken: toToken,
            toToken: fromToken,
            fromAmount: toAmount,
            toAmount: fromAmount
        )
    }

    private static func scaleValue(for token: KeeperCore.Token) -> BigUInt? {
        switch token {
        case let .ton(tonToken):
            switch tonToken {
            case .ton:
                return nil
            case let .jetton(item):
                return item.jettonInfo.scaleValue
            }
        case .tron:
            return nil
        }
    }

    private static func fractionDigits(for token: KeeperCore.Token) -> Int {
        token.fractionDigits
    }

    private static func convertRawToUI(_ raw: BigUInt, token: KeeperCore.Token) -> BigUInt {
        guard let scale = scaleValue(for: token) else {
            return raw
        }

        let digits = fractionDigits(for: token)
        return BigUInt.mulFixed(raw, scale, fractionDigits: digits)
    }

    private static func convertUIToRaw(_ ui: BigUInt, token: KeeperCore.Token) -> BigUInt {
        guard let scale = scaleValue(for: token) else {
            return ui
        }
        let digits = fractionDigits(for: token)
        return BigUInt.divideRoundHalfUp(ui, scaleN: digits, by: scale, scaleD: digits, resultScale: digits)
    }
}

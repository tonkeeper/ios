import BigInt
import Foundation
import KeeperCore

struct NativeSwapTransactionConfirmationModel {
    var fromToken: KeeperCore.Token
    var toToken: KeeperCore.Token
    var fromAmount: BigUInt
    var toAmount: BigUInt
    var sendFormatted = ""
    var receiveFormatted = ""
    var rateFormatted = ""
    var confirmation: SwapConfirmation
}

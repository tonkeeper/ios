import Foundation
import KeeperCore
import TonTransport

enum LedgerConfirmConfirmItem {
    case transaction(Transaction)
    case transactions([Transaction])
    case signatureData(TonConnect.SignatureData)
}

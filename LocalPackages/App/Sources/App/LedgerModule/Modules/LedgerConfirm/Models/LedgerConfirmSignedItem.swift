import Foundation
import KeeperCore
import TonTransport

enum LedgerConfirmSignedItem {
    case transaction(Data)
    case proof(Data)
    case transactions([Data])
}

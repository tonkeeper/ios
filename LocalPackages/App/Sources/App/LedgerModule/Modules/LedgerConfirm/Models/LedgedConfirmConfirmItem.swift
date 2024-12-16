import Foundation
import KeeperCore
import TonTransport

enum LedgedConfirmConfirmItem {
  case transaction(Transaction)
  case signatureData(TonConnect.SignatureData)
}

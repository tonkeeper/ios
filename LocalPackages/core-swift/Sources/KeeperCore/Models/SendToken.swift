import Foundation
import TonSwift

public enum SendToken: Equatable {
  case ton
  case jetton(JettonItem)
}

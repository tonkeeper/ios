import Foundation

public enum Token: Equatable, Hashable {
  case ton
  case jetton(JettonItem)
}

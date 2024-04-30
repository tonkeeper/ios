import Foundation

public enum Token: Equatable {
  case ton
  case jetton(JettonItem)
}

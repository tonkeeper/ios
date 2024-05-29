import Foundation

public enum Token: Equatable {
  case ton
  case jetton(JettonItem)
}

public enum SwapToken: Equatable {
  case ton
  case jetton(Asset)
}

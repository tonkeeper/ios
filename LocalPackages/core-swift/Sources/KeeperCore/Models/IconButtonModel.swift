import Foundation

public enum IconButton {
  case send(Token, enabled: Bool = true)
  case receive(Token)
  case buySell
  case swap
  case scan
  case stake
}

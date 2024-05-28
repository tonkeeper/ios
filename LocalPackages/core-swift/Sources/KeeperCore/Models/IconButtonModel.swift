import Foundation

public enum IconButton {
  case send(Token)
  case receive(Token)
  case buySell
  case swap
  case scan
  case stake
  case deposit(JettonItem, StakingPool)
  case withdraw(JettonItem, StakingPool)
}

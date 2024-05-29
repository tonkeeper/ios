import Foundation

public enum IconButton {
  case send(Token)
  case receive(Token)
  case buySell
  case swap
  case scan
  case stake
  case deposit(StakingPool)
  case withdraw(StakingPool)
}

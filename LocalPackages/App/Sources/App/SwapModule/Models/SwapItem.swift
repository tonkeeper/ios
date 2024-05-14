import KeeperCore

struct SwapItem {
  let send: Token
  let receive: Token?
}

enum SwapField {
  case send
  case receive
}

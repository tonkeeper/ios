import Foundation

public enum DeeplinkScheme: String {
  case tonsign
  case tonkeeper
}

public enum DeeplinkParameter: String {
  case pk
  case boc
  case v
  case network
  case `return`
}

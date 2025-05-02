import Foundation

public enum Network {
  case mainnet
  
  public var networkURL: URL {
    switch self {
    case .mainnet:
      URL(string: "https://api.trongrid.io/")!
    }
  }
}

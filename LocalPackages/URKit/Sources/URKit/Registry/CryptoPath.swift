import Foundation

public struct CryptoPath: Equatable {
  public var components: [CBOR] = []
  
  public init(cbor: CBOR) throws {
    switch cbor {
    case .array(let arr):
      var newComponents = Array<CBOR>()
      for item in arr {
        newComponents.append(item)
      }
      components = newComponents
    default:
      throw CryptoKeyPathError.invalidCBORType
    }
  }
  
  public init(string: String) throws {
    String(string).split(separator: "/").forEach { component in
      if component == "m" {
        return
      }
      
      let value = component.replacingOccurrences(of: "'", with: "")
      if let value = UInt64(value) {
        components.append(.unsigned(value))
      }
      
      if component.hasSuffix("'") {
        components.append(.simple(.true))
      }
    }
  }
}

public extension String {
  init(_ value: CryptoPath) {
    var path = "m"
    for component in value.components {
      switch component {
      case .simple(let value):
        if (value == .true) {
          path += "'"
        }
      case .unsigned(let value):
        path += "/\(value)"
      default:
        break
      }
    }
    self = path
  }
}

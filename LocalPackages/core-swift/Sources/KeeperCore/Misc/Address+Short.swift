import Foundation
import TonSwift

public extension Address {
  func toShortString(bounceable: Bool, isTestonly: Bool = false) -> String {
    let string = self.toString(testOnly: isTestonly, bounceable: bounceable)
    let leftPart = string.prefix(4)
    let rightPart = string.suffix(4)
    return "\(leftPart)...\(rightPart)"
  }
  
  func toShortRawString() -> String {
    let string = self.toRaw()
    let leftPart = string.prefix(4)
    let rightPart = string.suffix(4)
    return "\(leftPart)...\(rightPart)"
  }
}

public extension FriendlyAddress {
  func toShort() -> String {
    let string = self.toString()
    let leftPart = string.prefix(4)
    let rightPart = string.suffix(4)
    return "\(leftPart)...\(rightPart)"
  }
}

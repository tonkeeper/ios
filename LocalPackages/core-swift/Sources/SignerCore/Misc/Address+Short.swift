import Foundation
import TonSwift

public extension Address {
  func toShortString(bounceable: Bool) -> String {
    let string = self.toString(bounceable: bounceable)
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

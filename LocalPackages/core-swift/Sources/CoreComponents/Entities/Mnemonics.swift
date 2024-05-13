import Foundation

public struct Mnemonics: Codable {
  public let mnemonics: [String: Mnemonic]
  
  public init(mnemonics: [String : Mnemonic]) {
    self.mnemonics = mnemonics
  }
}

import Foundation
import TonSwift

public struct Mnemonic: Equatable, Codable {
    public enum Error: Swift.Error {
        case incorrectMnemonicWords
    }
    
    public var mnemonicWords: [String]
    
    public init(mnemonicWords: [String]) throws {
        guard TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: mnemonicWords) else {
            throw Error.incorrectMnemonicWords
        }
        self.mnemonicWords = mnemonicWords
    }
    
    public init(from decoder: Decoder) throws {
        if var container = try? decoder.unkeyedContainer() {
            var array = [String]()
            while !container.isAtEnd {
                array.append(try container.decode(String.self))
            }
            self.mnemonicWords = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mnemonicWords = try container.decode([String].self, forKey: .mnemonicWords)
    }
}

import Foundation

public struct Mnemonic: Equatable, Codable {
    public enum Failure: Error {
        case incorrectMnemonicWords
    }

    public var mnemonicWords: [String]

    public init(mnemonicWords: [String]) throws(Failure) {
        guard DerivationType.guessByWords(mnemonicWords).isKnown else {
            throw .incorrectMnemonicWords
        }
        self.mnemonicWords = mnemonicWords
    }

    public init(from decoder: Decoder) throws {
        if var container = try? decoder.unkeyedContainer() {
            var array = [String]()
            while !container.isAtEnd {
                try array.append(container.decode(String.self))
            }
            self.mnemonicWords = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mnemonicWords = try container.decode([String].self, forKey: .mnemonicWords)
    }
}

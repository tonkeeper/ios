import Foundation

extension String {
    var multilineReceiveAddress: String {
        let characters = Array(self)
        guard characters.count > 16 else {
            return self
        }

        let midpoint = Int(ceil(Double(characters.count) / 2.0))
        return String(characters[..<midpoint]) + "\n" + String(characters[midpoint...])
    }
}

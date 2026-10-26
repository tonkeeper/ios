import Foundation

extension StringProtocol {
    var isEVMAddress: Bool {
        count == 42
            && lowercased().hasPrefix("0x")
            && dropFirst(2).allSatisfy { $0.isASCII && $0.isHexDigit }
    }
}

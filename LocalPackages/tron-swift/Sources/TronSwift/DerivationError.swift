import Foundation

public enum DerivationError: Swift.Error {
    case invalidIndex(UInt32)
    case nonHardenedDeriveFailed
    case invalidPath(String)
}

import Foundation

public struct Passcode: Codable, Equatable {
    enum Error: Swift.Error {
        case incorrentLength(Int)
    }
    
    public static let length = 4
    private let value: String
    
    public init(value: String) throws {
        guard value.count == Passcode.length else {
            throw Error.incorrentLength(value.count)
        }
        self.value = value
    }
}

import Foundation
import TonSwift

public enum Network: Int, Hashable {
    case mainnet = -239
    case testnet = -3

    public var isMainnet: Bool {
        self == .mainnet
    }
}

public extension Network {
    /// ChainKit detects TON addresses by format alone; the test-only flag lives in the tag byte and
    /// stays invisible to it, so a testnet address remains a valid TON candidate on mainnet.
    func matchesTonAddress(_ address: FriendlyAddress) -> Bool {
        address.isTestOnly == (self == .testnet)
    }

    /// Raw addresses carry no network flag and belong to either network.
    func matchesTonAddress(_ string: String) -> Bool {
        guard let friendlyAddress = try? FriendlyAddress(string: string) else { return true }
        return matchesTonAddress(friendlyAddress)
    }
}

extension Network: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(int: rawValue, bits: .rawValueLength)
    }

    public static func loadFrom(slice: Slice) throws -> Network {
        return try slice.tryLoad { s in
            let rawValue = try s.loadInt(bits: .rawValueLength)
            guard let network = Network(rawValue: rawValue) else {
                throw TonSwift.TonError.custom("Invalid network code")
            }
            return network
        }
    }
}

private extension Int {
    static let rawValueLength = 16
}

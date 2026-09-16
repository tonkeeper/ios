import Foundation
import TonSwift

public enum Network: Int, Hashable {
    case mainnet = -239
    case testnet = -3
    case tetra = 662_387

    public var isMainnet: Bool {
        switch self {
        case .mainnet:
            true
        case .tetra, .testnet:
            false
        }
    }
}

public extension Network {
    var walletNetworkGlobalId: Int {
        switch self {
        case .mainnet, .tetra:
            return Network.mainnet.rawValue
        case .testnet:
            return Network.testnet.rawValue
        }
    }

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

/// storage uses 16 bits per network type, tetra value exeedes 16bit limits
/// So I decided to use mapping instead of storage migration
private let networkRawValueTransform: [Int: Int16] = [
    Network.mainnet.rawValue: -239,
    Network.testnet.rawValue: -3,
    Network.tetra.rawValue: 42,
]

private let networkReverseRawValueTransform: [Int16: Int] = [
    -239: Network.mainnet.rawValue,
    -3: Network.testnet.rawValue,
    42: Network.tetra.rawValue,
]

extension Network: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(int: networkRawValueTransform[rawValue] ?? rawValue, bits: .rawValueLength)
    }

    public static func loadFrom(slice: Slice) throws -> Network {
        return try slice.tryLoad { s in
            let rawValue = try Int16(s.loadInt(bits: .rawValueLength))
            guard let network = Network(rawValue: networkReverseRawValueTransform[rawValue] ?? Int(rawValue)) else {
                throw TonSwift.TonError.custom("Invalid network code")
            }
            return network
        }
    }
}

private extension Int {
    static let rawValueLength = 16
}

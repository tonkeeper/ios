import BigInt
import Foundation

public enum Parameter {
    case address(Address)
    case bigUInt(BigUInt)

    func encode() -> Data {
        switch self {
        case let .address(address):
            return padding(data: address.notPrefixed())
        case let .bigUInt(value):
            return padding(data: value.serialize())
        }
    }

    private func padding(data: Data) -> Data {
        Data(repeating: 0, count: max(0, 32 - data.count)) + data
    }
}

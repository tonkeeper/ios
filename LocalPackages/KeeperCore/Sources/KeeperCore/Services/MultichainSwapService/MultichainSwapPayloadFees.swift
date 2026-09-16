import BigInt
import ChainKit

struct MultichainSwapPayloadFees {
    private let storage: [String: MultichainSwapFeeSnapshot]

    init(_ storage: [String: any Fee] = [:]) {
        self.storage = storage.mapValues(MultichainSwapFeeSnapshot.init)
    }

    func fee(for payloadId: String) throws(MultichainSwapExecutionFailure) -> (any Fee)? {
        try storage[payloadId]?.makeFee()
    }

    var payloadIds: [String] {
        Array(storage.keys)
    }
}

extension MultichainSwapPayloadFees: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, any Fee)...) {
        var snapshots = [String: MultichainSwapFeeSnapshot]()
        for (payloadId, fee) in elements where snapshots[payloadId] == nil {
            snapshots[payloadId] = MultichainSwapFeeSnapshot(fee: fee)
        }
        storage = snapshots
    }
}

private enum MultichainSwapFeeSnapshot: Hashable {
    case none
    case value(amount: String)
    case gas(limit: String, price: String, amount: String)
    case eip1559(
        limit: String,
        networkPrice: String,
        maxPrice: String,
        minerPrice: String,
        amount: String
    )
    case unsupported(typeName: String, amount: String)

    init(fee: any Fee) {
        switch fee {
        case is FeeNone:
            self = .none
        case let fee as FeeValue:
            self = .value(amount: fee.amount.description)
        case let fee as FeeGas:
            self = .gas(
                limit: fee.limit.description,
                price: fee.price.description,
                amount: fee.amount.description
            )
        case let fee as FeeEip1559:
            self = .eip1559(
                limit: fee.limit.description,
                networkPrice: fee.networkPrice.description,
                maxPrice: fee.maxPrice.description,
                minerPrice: fee.minerPrice.description,
                amount: fee.amount.description
            )
        default:
            self = .unsupported(
                typeName: String(reflecting: type(of: fee)),
                amount: fee.amount.description
            )
        }
    }

    func makeFee() throws(MultichainSwapExecutionFailure) -> any Fee {
        switch self {
        case .none:
            return FeeNone.shared
        case let .value(amount):
            return try FeeValue(amount: Self.bigInteger(amount, field: "amount"))
        case let .gas(limit, price, amount):
            return try FeeGas(
                limit: Self.bigInteger(limit, field: "limit"),
                price: Self.bigInteger(price, field: "price"),
                amount: Self.bigInteger(amount, field: "amount")
            )
        case let .eip1559(limit, networkPrice, maxPrice, minerPrice, amount):
            return try FeeEip1559(
                limit: Self.bigInteger(limit, field: "limit"),
                networkPrice: Self.bigInteger(networkPrice, field: "networkPrice"),
                maxPrice: Self.bigInteger(maxPrice, field: "maxPrice"),
                minerPrice: Self.bigInteger(minerPrice, field: "minerPrice"),
                amount: Self.bigInteger(amount, field: "amount")
            )
        case let .unsupported(typeName, _):
            throw .internal(reason: "unsupported pinned ChainKit fee type: \(typeName)")
        }
    }

    private static func bigInteger(
        _ value: String,
        field: String
    ) throws(MultichainSwapExecutionFailure) -> BignumBigInteger {
        guard BigUInt(value) != nil else {
            throw .internal(reason: "invalid pinned ChainKit fee \(field): \(value)")
        }
        return BignumBigInteger.Companion.shared.parseString(string: value, base: 10)
    }
}

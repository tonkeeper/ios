import ChainKit
import Foundation

/// Awaits a Kotlin suspend function bridged as a completion handler, treating a
/// nil value as a failure (use for non-null Kotlin return types).
func bridgeKotlin<T>(
    _ body: (@escaping @Sendable (T?, Error?) -> Void) -> Void
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        body { value, error in
            if let value {
                continuation.resume(returning: value)
            } else {
                continuation.resume(throwing: error ?? NSError(domain: "ChainKitBridge", code: -1))
            }
        }
    }
}

/// Awaits a Kotlin suspend function with a nullable result: a nil value with no
/// error is a legitimate Kotlin null, not a failure.
func bridgeKotlinOptional<T>(
    _ body: (@escaping @Sendable (T?, Error?) -> Void) -> Void
) async throws -> T? {
    try await withCheckedThrowingContinuation { continuation in
        body { value, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: value)
            }
        }
    }
}

func perpsValue<T: AnyObject>(_ result: PerpsRes<T>) throws -> T {
    if let error = result.error {
        throw NSError(
            domain: "ChainKitPerpsTrade",
            code: 1,
            userInfo: [
                "KotlinException": error,
                NSLocalizedDescriptionKey: error.message ?? "invalid transaction",
            ]
        )
    }
    guard let value = result.getOrNull() else {
        throw PerpsTradingError.protocolFailure("perps planner returned neither a value nor an error")
    }
    return value
}

func perpsTradeException(from error: Error) -> PerpsTradeException? {
    if let typed = error as? PerpsTradeException { return typed }
    return (error as NSError).userInfo["KotlinException"] as? PerpsTradeException
}

extension Data {
    var asKotlinByteArray: KotlinByteArray {
        let array = KotlinByteArray(size: Int32(count))
        for (index, byte) in enumerated() {
            array.set(index: Int32(index), value: Int8(bitPattern: byte))
        }
        return array
    }
}

extension KotlinByteArray {
    var asData: Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(Int(size))
        for index in 0 ..< size {
            bytes.append(UInt8(bitPattern: get(index: index)))
        }
        return Data(bytes)
    }
}

import Foundation
@testable import KeeperCore
import TronSwift
import XCTest

final class WalletMigrationTronBalanceLoadingTests: XCTestCase {
    func test_loadDeduplicatesAddressesAndMapsBalanceToEveryWallet() async throws {
        let sharedAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let otherAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 2, count: 20))
        )
        let recorder = TronBalanceRequestRecorder()

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: [
                "first": sharedAddress,
                "duplicate": sharedAddress,
                "other": otherAddress,
            ]
        ) { address in
            await recorder.load(address: address)
        }

        let requestedAddresses = await recorder.requestedAddresses
        XCTAssertEqual(requestedAddresses.count, 2)
        XCTAssertEqual(Set(requestedAddresses), Set([sharedAddress.base58, otherAddress.base58]))
        XCTAssertEqual(balances["first"], balances["duplicate"])
        XCTAssertEqual(balances["first"], TronBalance(amount: 1, trxAmount: 10))
        XCTAssertEqual(balances["other"], TronBalance(amount: 2, trxAmount: 20))
    }

    func test_loadUsesBatchWithoutPerAddressRequests() async throws {
        let firstAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let secondAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 2, count: 20))
        )
        let recorder = TronBalanceRequestRecorder()

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["first": firstAddress, "second": secondAddress],
            batchLoad: { addresses in
                Dictionary(uniqueKeysWithValues: addresses.map {
                    ($0.base58, TronBalance(amount: 7, trxAmount: 8))
                })
            },
            loadBalance: { address in
                await recorder.load(address: address)
            }
        )

        let requestedAddresses = await recorder.requestedAddresses
        XCTAssertTrue(requestedAddresses.isEmpty)
        XCTAssertEqual(balances["first"], TronBalance(amount: 7, trxAmount: 8))
        XCTAssertEqual(balances["second"], TronBalance(amount: 7, trxAmount: 8))
    }

    func test_loadFallsBackPerAddressWhenBatchFails() async throws {
        let firstAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let secondAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 2, count: 20))
        )
        let recorder = TronBalanceRequestRecorder()

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["first": firstAddress, "second": secondAddress],
            batchLoad: { _ in
                throw NSError(domain: "test", code: 1)
            },
            loadBalance: { address in
                await recorder.load(address: address)
            }
        )

        let requestedAddresses = await recorder.requestedAddresses
        XCTAssertEqual(Set(requestedAddresses), Set([firstAddress.base58, secondAddress.base58]))
        XCTAssertEqual(balances["first"], TronBalance(amount: 1, trxAmount: 10))
        XCTAssertEqual(balances["second"], TronBalance(amount: 2, trxAmount: 20))
    }

    func test_loadTopsUpAddressesMissingFromBatch() async throws {
        let coveredAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let missingAddress = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 2, count: 20))
        )
        let recorder = TronBalanceRequestRecorder()

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["covered": coveredAddress, "missing": missingAddress],
            batchLoad: { _ in
                [coveredAddress.base58: TronBalance(amount: 7, trxAmount: 8)]
            },
            loadBalance: { address in
                await recorder.load(address: address)
            }
        )

        let requestedAddresses = await recorder.requestedAddresses
        XCTAssertEqual(requestedAddresses, [missingAddress.base58])
        XCTAssertEqual(balances["covered"], TronBalance(amount: 7, trxAmount: 8))
        XCTAssertEqual(balances["missing"], TronBalance(amount: 2, trxAmount: 20))
    }

    func test_loadUsesStaleFallbackWhenRefreshFails() async throws {
        let address = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let stale = TronBalance(amount: 7, trxAmount: 8)

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["wallet": address],
            batchLoad: { _ in [:] },
            fallbackBalance: { _ in stale },
            loadBalance: { _ in throw TestError.offline }
        )

        XCTAssertEqual(balances["wallet"], stale)
    }

    func test_loadSuccessfulZeroDoesNotUseStaleFallback() async throws {
        let address = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let fallbackRecorder = FallbackRequestRecorder()

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["wallet": address],
            batchLoad: { _ in [:] },
            fallbackBalance: { address in
                await fallbackRecorder.load(address: address)
            },
            loadBalance: { _ in TronBalance(amount: 0, trxAmount: 0) }
        )

        let fallbackRequests = await fallbackRecorder.requestedAddresses
        XCTAssertTrue(fallbackRequests.isEmpty)
        XCTAssertEqual(balances["wallet"], TronBalance(amount: 0, trxAmount: 0))
    }

    func test_loadDoesNotInventBalanceWhenRefreshAndFallbackFail() async throws {
        let address = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )

        let balances = await WalletMigrationTronBalanceLoading.load(
            addressByWalletId: ["wallet": address],
            batchLoad: { _ in [:] },
            fallbackBalance: { _ in nil },
            loadBalance: { _ in throw TestError.offline }
        )

        XCTAssertTrue(balances.isEmpty)
    }

    func test_cancellingBatchDoesNotStartPerAddressFallback() async throws {
        let address = try TronSwift.Address(
            raw: Data([0x41] + Array(repeating: 1, count: 20))
        )
        let batchProbe = BatchCancellationProbe()
        let recorder = TronBalanceRequestRecorder()

        let task = Task {
            await WalletMigrationTronBalanceLoading.load(
                addressByWalletId: ["wallet": address],
                batchLoad: { _ in
                    await batchProbe.markStarted()
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    return [:]
                },
                loadBalance: { address in
                    await recorder.load(address: address)
                }
            )
        }

        await batchProbe.waitUntilStarted()
        task.cancel()
        let balances = await task.value

        let requestedAddresses = await recorder.requestedAddresses
        XCTAssertTrue(requestedAddresses.isEmpty)
        XCTAssertTrue(balances.isEmpty)
    }
}

private actor TronBalanceRequestRecorder {
    private(set) var requestedAddresses = [String]()

    func load(address: TronSwift.Address) -> TronBalance {
        requestedAddresses.append(address.base58)
        let marker = address.raw.last ?? 0
        return TronBalance(
            amount: .init(marker),
            trxAmount: .init(marker * 10)
        )
    }
}

private actor FallbackRequestRecorder {
    private(set) var requestedAddresses = [String]()

    func load(address: TronSwift.Address) -> TronBalance {
        requestedAddresses.append(address.base58)
        return TronBalance(amount: 99, trxAmount: 99)
    }
}

private actor BatchCancellationProbe {
    private var started = false

    func markStarted() {
        started = true
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }
}

private enum TestError: Error {
    case offline
}

import Foundation
@testable import TKCore
@testable import TKServices
import XCTest

final class CampaignAttributionStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "CampaignAttributionStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func test_firstTouchKeepsEachProviderIndependent() async {
        let store = makeStore()
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let branch = CampaignAttributionRecord(
            provider: .branch,
            payload: ["~campaign": .string("branch-campaign")],
            resolvedDeeplink: "tonkeeper://swap?ft=TON&tt=USDT",
            capturedAt: capturedAt
        )
        let linkrunner = CampaignAttributionRecord(
            provider: .linkrunner,
            payload: ["deeplink": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT")],
            resolvedDeeplink: "https://app.tonkeeper.com/swap?ft=TON&tt=USDT",
            capturedAt: capturedAt
        )

        let storedBranch = await store.capture(branch)
        let storedAgain = await store.capture(
            CampaignAttributionRecord(
                provider: .branch,
                payload: ["~campaign": .string("later")],
                resolvedDeeplink: nil,
                capturedAt: capturedAt.addingTimeInterval(10)
            )
        )
        let storedLinkrunner = await store.capture(linkrunner)

        let records = await store.records()
        XCTAssertTrue(storedBranch)
        XCTAssertFalse(storedAgain)
        XCTAssertTrue(storedLinkrunner)
        XCTAssertEqual(records, [branch, linkrunner])
    }

    func test_recordsSurviveANewStore() async {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let record = CampaignAttributionRecord(
            provider: .linkrunner,
            payload: ["campaignData": .object(["type": .string("INORGANIC")])],
            resolvedDeeplink: nil,
            capturedAt: capturedAt
        )
        let stored = await makeStore().capture(record)

        let restored = await makeStore().record(for: .linkrunner)
        XCTAssertTrue(stored)
        XCTAssertEqual(restored, record)
    }

    func test_consumeRemovesOnlyTheRequestedProvider() async {
        let store = makeStore()
        let branch = makeRecord(provider: .branch)
        let linkrunner = makeRecord(provider: .linkrunner)
        _ = await store.capture(branch)
        _ = await store.capture(linkrunner)

        let consumed = await store.consume(.branch)
        let remaining = await makeStore().records()

        XCTAssertEqual(consumed, branch)
        XCTAssertEqual(remaining, [linkrunner])
    }

    func test_consumeAllRemovesBothRecords() async {
        let store = makeStore()
        _ = await store.capture(makeRecord(provider: .branch))
        _ = await store.capture(makeRecord(provider: .linkrunner))

        let consumed = await store.consumeAll()
        let remaining = await store.records()

        XCTAssertEqual(consumed.map(\.provider), [.branch, .linkrunner])
        XCTAssertTrue(remaining.isEmpty)
    }

    func test_concurrentCapturesKeepOneRecordPerProvider() async {
        let store = makeStore()
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 40 {
                group.addTask {
                    let provider: CampaignAttributionProvider = index.isMultiple(of: 2) ? .branch : .linkrunner
                    _ = await store.capture(
                        CampaignAttributionRecord(
                            provider: provider,
                            payload: ["index": .string("\(index)")],
                            resolvedDeeplink: nil,
                            capturedAt: Date(timeIntervalSince1970: TimeInterval(index))
                        )
                    )
                }
            }
        }

        let records = await store.records()
        XCTAssertEqual(records.map(\.provider), [.branch, .linkrunner])
    }

    func test_unreadableSnapshotDoesNotBlockTheNextCapture() async {
        defaults.set(Data("not-json".utf8), forKey: CampaignAttributionStorage.userDefaultsKey)
        let store = makeStore()
        let record = makeRecord(provider: .branch)

        let stored = await store.capture(record)
        let restored = await store.records()

        XCTAssertTrue(stored)
        XCTAssertEqual(restored, [record])
    }

    private func makeStore() -> CampaignAttributionStore {
        CampaignAttributionStore(userDefaults: defaults)
    }

    private func makeRecord(provider: CampaignAttributionProvider) -> CampaignAttributionRecord {
        CampaignAttributionRecord(
            provider: provider,
            payload: ["provider": .string(provider.rawValue)],
            resolvedDeeplink: nil,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

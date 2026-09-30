import Foundation
@testable import KeeperCore
import TKFeatureFlags
import XCTest

final class RaffleLoaderTests: XCTestCase {
    func test_changedDebugDateReplacesInFlightRequestAndIgnoresItsCompletion() async {
        let recorder = RaffleRequestRecorder()
        let store = RaffleStore()
        let settings = AppSettingsStub()
        let loader = RaffleLoader(
            loadRaffles: { walletId, lang, ids, debugNow, isNewUser in
                await recorder.load(
                    walletId: walletId,
                    lang: lang,
                    ids: ids,
                    debugNow: debugNow,
                    isNewUser: isNewUser
                )
            },
            raffleStore: store,
            appSettings: settings
        )

        let firstDate = Date(timeIntervalSince1970: 1000)
        let secondDate = Date(timeIntervalSince1970: 2000)
        settings.raffleIsNewUser = true
        settings.raffleDebugNow = firstDate

        let first = Task {
            await loader.loadRafflesNow(walletId: "wallet", lang: "en", ids: ["raffle"])
        }
        await recorder.waitForRequestCount(1)

        settings.raffleDebugNow = secondDate
        let second = Task {
            await loader.loadRafflesNow(walletId: "wallet", lang: "en", ids: ["raffle"])
        }
        await recorder.waitForRequestCount(2)

        await recorder.completeRequest(at: 0, with: [raffle(id: "stale")])
        await recorder.completeRequest(at: 1, with: [raffle(id: "current")])
        await first.value
        await second.value

        let debugDates = await recorder.debugDates
        let newUserValues = await recorder.newUserValues
        XCTAssertEqual(debugDates, [firstDate, secondDate])
        XCTAssertEqual(newUserValues, [true, true])
        XCTAssertEqual(store.getState().map(\.id), ["current"])
    }

    func test_olderEnqueuedWalletLoadCannotReplaceNewerOne() async {
        let recorder = RaffleRequestRecorder()
        let store = RaffleStore()
        let loader = RaffleLoader(
            loadRaffles: { walletId, lang, ids, debugNow, isNewUser in
                await recorder.load(
                    walletId: walletId,
                    lang: lang,
                    ids: ids,
                    debugNow: debugNow,
                    isNewUser: isNewUser
                )
            },
            raffleStore: store,
            appSettings: AppSettingsStub()
        )

        let current = Task {
            await loader.loadRafflesNow(walletId: "wallet-b", lang: "en", ids: nil, operationID: 2)
        }
        await recorder.waitForRequestCount(1)

        await loader.loadRafflesNow(walletId: "wallet-a", lang: "en", ids: nil, operationID: 1)
        await recorder.completeRequest(at: 0, with: [raffle(id: "wallet-b")])
        await current.value

        let walletIds = await recorder.walletIds
        let newUserValues = await recorder.newUserValues
        XCTAssertEqual(walletIds, ["wallet-b"])
        XCTAssertEqual(newUserValues, [false])
        XCTAssertEqual(store.getState().map(\.id), ["wallet-b"])
    }
}

private actor RaffleRequestRecorder {
    struct Request {
        let walletId: String
        let debugNow: Date?
        let isNewUser: Bool
        let continuation: CheckedContinuation<[MultichainRaffle], Never>
    }

    private var requests: [Request] = []

    var debugDates: [Date?] {
        requests.map(\.debugNow)
    }

    var walletIds: [String] {
        requests.map(\.walletId)
    }

    var newUserValues: [Bool] {
        requests.map(\.isNewUser)
    }

    func load(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
    ) async -> [MultichainRaffle] {
        await withCheckedContinuation { continuation in
            requests.append(
                Request(
                    walletId: walletId,
                    debugNow: debugNow,
                    isNewUser: isNewUser,
                    continuation: continuation
                )
            )
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }

    func completeRequest(at index: Int, with raffles: [MultichainRaffle]) {
        requests[index].continuation.resume(returning: raffles)
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
    var raffleDebugNow: Date?
}

private func raffle(id: String) -> MultichainRaffle {
    MultichainRaffle(
        id: id,
        status: .notJoined,
        hero: MultichainRaffleHero(image: "", badgeIconId: nil),
        title: "",
        subtitle: "",
        startsAt: .distantPast,
        endsAt: .distantFuture,
        prizesRevealAt: nil,
        compactBanner: MultichainRaffleCompactBanner(defaultTitle: "", activeTitle: "", iconId: ""),
        prizesHeader: "",
        statusBadge: nil,
        prizes: [],
        tasks: [],
        milestones: [],
        cta: MultichainRaffleCTA(title: "", action: .deeplink, payload: ""),
        progress: nil
    )
}

import Foundation
@testable import TKCore
@testable import TKServices
import XCTest

final class CampaignAttributionDecodingTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func test_branchCanonicalURLResolvesToTheSwapLink() {
        let payload: [String: AttributionJSON] = [
            "+clicked_branch_link": .bool(true),
            "$canonical_url": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
        ]

        let record = CampaignAttributionDecoding.makeRecord(
            provider: .branch,
            payload: payload,
            capturedAt: capturedAt
        )

        XCTAssertEqual(record?.resolvedDeeplink, "https://app.tonkeeper.com/swap?ft=TON&tt=USDT")
    }

    func test_branchDeeplinkPathResolvesToTheCustomSchemeSwapLink() {
        let payload: [String: AttributionJSON] = [
            "+clicked_branch_link": .number(1),
            "$ios_deeplink_path": .string("tonkeeper://swap?ft=TON&tt=USDT"),
            "$canonical_url": .string("https://go.tonkeeper.com/campaign"),
        ]

        XCTAssertEqual(
            CampaignAttributionDecoding.branchDestination(payload),
            "tonkeeper://swap?ft=TON&tt=USDT"
        )
    }

    func test_branchRelativePathBecomesATonkeeperSwapLink() {
        let payload: [String: AttributionJSON] = [
            "~campaign": .string("autumn"),
            "$deeplink_path": .string("/swap?ft=TON&tt=USDT"),
        ]

        XCTAssertEqual(
            CampaignAttributionDecoding.branchDestination(payload),
            "tonkeeper://swap?ft=TON&tt=USDT"
        )
    }

    func test_ordinaryAppOpenIsNotBranchFirstTouch() {
        let nonBranchOpen: [String: AttributionJSON] = [
            "+clicked_branch_link": .bool(false),
            "+non_branch_link": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
        ]
        XCTAssertNil(CampaignAttributionDecoding.branchDestination(nonBranchOpen))
        XCTAssertNil(
            CampaignAttributionDecoding.makeRecord(
                provider: .branch,
                payload: nonBranchOpen,
                capturedAt: capturedAt
            )
        )

        let canonicalWithoutCampaign: [String: AttributionJSON] = [
            "+clicked_branch_link": .bool(false),
            "$canonical_url": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
        ]
        XCTAssertNil(
            CampaignAttributionDecoding.makeRecord(
                provider: .branch,
                payload: canonicalWithoutCampaign,
                capturedAt: capturedAt
            )
        )
    }

    func test_branchOpenWithoutAttributionIsIgnored() {
        let payload: [String: AttributionJSON] = [
            "+clicked_branch_link": .bool(false),
            "+is_first_session": .bool(true),
        ]

        XCTAssertNil(
            CampaignAttributionDecoding.makeRecord(
                provider: .branch,
                payload: payload,
                capturedAt: capturedAt
            )
        )
    }

    func test_linkrunnerSwapDeeplinkIsKept() {
        let payload: [String: AttributionJSON] = [
            "attributionSource": .string("META"),
            "deeplink": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
            "campaignData": .object([
                "id": .string("campaign-1"),
                "type": .string("INORGANIC"),
            ]),
        ]

        let record = CampaignAttributionDecoding.makeRecord(
            provider: .linkrunner,
            payload: payload,
            capturedAt: capturedAt
        )

        XCTAssertEqual(record?.resolvedDeeplink, "https://app.tonkeeper.com/swap?ft=TON&tt=USDT")
        XCTAssertEqual(record?.provider, .linkrunner)
    }

    func test_linkrunnerCustomSchemeDeeplinkIsKept() {
        let payload: [String: AttributionJSON] = [
            "deeplink": .string("tonkeeper://swap?ft=TON&tt=USDT"),
        ]

        XCTAssertEqual(
            CampaignAttributionDecoding.linkrunnerDestination(payload),
            "tonkeeper://swap?ft=TON&tt=USDT"
        )
    }

    func test_linkrunnerOrganicInstallWithoutADeeplinkIsIgnored() {
        let payload: [String: AttributionJSON] = [
            "attributionSource": .string("ORGANIC"),
            "campaignData": .object([
                "id": .string("organic"),
                "type": .string("ORGANIC"),
            ]),
        ]

        XCTAssertNil(
            CampaignAttributionDecoding.makeRecord(
                provider: .linkrunner,
                payload: payload,
                capturedAt: capturedAt
            )
        )
    }

    func test_trackingHostIsStoredButNotRouted() {
        let payload: [String: AttributionJSON] = [
            "deeplink": .string("https://link.tonkeeper.com/campaign"),
            "campaignData": .object(["type": .string("INORGANIC")]),
        ]

        let record = CampaignAttributionDecoding.makeRecord(
            provider: .linkrunner,
            payload: payload,
            capturedAt: capturedAt
        )

        XCTAssertNotNil(record)
        XCTAssertNil(record?.resolvedDeeplink)
    }

    func test_cachedBranchDataDoesNotRouteAgain() {
        let payload: [String: AttributionJSON] = [
            "+clicked_branch_link": .bool(false),
            "$canonical_url": .string("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
        ]

        XCTAssertTrue(
            CampaignAttributionDecoding.shouldRoute(
                provider: .branch,
                payload: payload,
                isFirstTouch: true
            )
        )
        XCTAssertFalse(
            CampaignAttributionDecoding.shouldRoute(
                provider: .branch,
                payload: payload,
                isFirstTouch: false
            )
        )
    }

    func test_trackingLinkIsNotAnAppDeeplink() {
        XCTAssertNil(CampaignAttributionDecoding.appLink("https://go.tonkeeper.com/campaign"))
        XCTAssertNil(CampaignAttributionDecoding.appLink("https://link.tonkeeper.com/campaign"))
        XCTAssertNil(CampaignAttributionDecoding.appLink("https://x1zxr.app.link/swap"))
        XCTAssertNil(CampaignAttributionDecoding.appLink("https://x1zxr-alternate.app.link/swap"))
        XCTAssertEqual(
            CampaignAttributionDecoding.appLink("https://app.tonkeeper.com/swap?ft=TON&tt=USDT"),
            "https://app.tonkeeper.com/swap?ft=TON&tt=USDT"
        )
        XCTAssertEqual(
            CampaignAttributionDecoding.appLink("https://app.keeperwallet.com/swap?ft=TON&tt=USDT"),
            "https://app.keeperwallet.com/swap?ft=TON&tt=USDT"
        )
        XCTAssertEqual(
            CampaignAttributionDecoding.appLink("tonkeeper://swap?ft=TON&tt=USDT"),
            "tonkeeper://swap?ft=TON&tt=USDT"
        )
        XCTAssertEqual(
            CampaignAttributionDecoding.appLink("keeper://swap?ft=TON&tt=USDT"),
            "keeper://swap?ft=TON&tt=USDT"
        )
        XCTAssertNil(CampaignAttributionDecoding.appLink(nil))
    }

    func test_placeholderCredentialsStayDisabled() {
        XCTAssertNil(CampaignAttributionCredentials.configured("REPLACE_WITH_BRANCH_KEY_LIVE"))
        XCTAssertNil(CampaignAttributionCredentials.configured("  "))
        XCTAssertEqual(CampaignAttributionCredentials.configured(" key_live_example "), "key_live_example")
    }
}

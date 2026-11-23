@testable import App
import KeeperCore
import XCTest

@MainActor
final class RampMerchantProvidersTests: XCTestCase {
    func test_providers_listTheMethodsEachMerchantTakesInTheCurrency() throws {
        let providers = try RampMerchantService.providers(detail: Self.detail(), merchants: Self.merchants(), fiat: "USD")

        XCTAssertEqual(providers.map(\.id), ["mercuryo", "transak"])
        XCTAssertEqual(providers.map(\.methodTitles), [["Card", "Apple Pay"], ["Card", "Bank transfer"]])
        XCTAssertEqual(providers.first?.imageURL, URL(string: "https://example.com/mercuryo.png"))
    }

    func test_providers_leaveOutP2PAndMerchantsWithoutAMethodInTheCurrency() throws {
        let providers = try RampMerchantService.providers(detail: Self.detail(), merchants: Self.merchants(), fiat: "EUR")

        // Only Transak sells in EUR; the P2P merchant is no provider.
        XCTAssertEqual(providers.map(\.id), ["transak"])
        XCTAssertEqual(providers.first?.methodTitles, ["Card"])
    }

    func test_isMoonPay_marksMoonPaysWidget() {
        let provider = { (id: String) in RampMerchantProvider(id: id, title: "", imageURL: nil, methodTitles: []) }

        XCTAssertTrue(provider("moonpay").isMoonPay)
        XCTAssertTrue(provider("MoonPay_widget").isMoonPay)
        XCTAssertFalse(provider("mercuryo").isMoonPay)
    }

    func test_moonPayWidgetMethodTypes_areTheWidgetsInTheCurrency() throws {
        let json = #"""
        {
            "assetId":"ton/usdt","symbol":"USDT","decimals":6,"stablecoin":true,"extraIdRequired":false,
            "paymentMethods":[
                {"type":"card","name":"Card","image":"","isP2P":false,"providers":[
                    {"merchantId":"moonpay","fiat":"USD"},
                    {"merchantId":"mercuryo","fiat":"USD"}
                ]},
                {"type":"paypal","name":"PayPal","image":"","isP2P":false,"providers":[
                    {"merchantId":"moonpay","fiat":"EUR"}
                ]},
                {"type":"bank_transfer","name":"Bank transfer","image":"","isP2P":false,"providers":[
                    {"merchantId":"transak","fiat":"USD"}
                ]}
            ]
        }
        """#
        let detail = try JSONDecoder().decode(OnRampAssetDetail.self, from: Data(json.utf8))

        XCTAssertEqual(RampMerchantService.moonPayWidgetMethodTypes(in: detail, fiat: "USD"), ["card"])
        XCTAssertEqual(RampMerchantService.moonPayWidgetMethodTypes(in: detail, fiat: "GBP"), [])
    }

    func test_moonPayWidgetTakes_onlyAMethodTheBackendListsMoonPayFor() throws {
        let json = #"""
        {
            "assetId":"ton/usdt","symbol":"USDT","decimals":6,"stablecoin":true,"extraIdRequired":false,
            "paymentMethods":[
                {"type":"card","name":"Card","image":"","isP2P":false,"providers":[
                    {"merchantId":"moonpay","fiat":"USD"},
                    {"merchantId":"mercuryo","fiat":"KZT"},
                    {"merchantId":"mercuryo","fiat":"RSD"},
                    {"merchantId":"transak","fiat":"RSD"}
                ]},
                {"type":"p2p","name":"P2P Express","image":"","isP2P":true,"providers":[
                    {"merchantId":"p2p","fiat":"KZT"}
                ]}
            ]
        }
        """#
        let detail = try JSONDecoder().decode(OnRampAssetDetail.self, from: Data(json.utf8))
        let takes = { (fiat: String, type: String?) in
            RampMerchantService.moonPayWidgetTakes(
                methodType: type,
                among: RampMerchantService.moonPayWidgetMethodTypes(in: detail, fiat: fiat)
            )
        }

        XCTAssertTrue(takes("USD", "card"))
        // Only Mercuryo (KZT) or Mercuryo and Transak (RSD) sell there: no MoonPay sign-in.
        XCTAssertFalse(takes("KZT", "card"))
        XCTAssertFalse(takes("RSD", "card"))
        XCTAssertFalse(takes("KZT", "p2p"))
        XCTAssertFalse(takes("USD", nil))
        // The methods are not loaded yet.
        XCTAssertFalse(RampMerchantService.moonPayWidgetTakes(methodType: "card", among: nil))
    }

    func test_methodTypes_areTheMerchantsInTheCurrency() throws {
        let detail = try Self.detail()

        XCTAssertEqual(RampMerchantService.methodTypes(of: "mercuryo", in: detail, fiat: "USD"), ["card", "apple_pay"])
        XCTAssertEqual(RampMerchantService.methodTypes(of: "mercuryo", in: detail, fiat: "EUR"), [])
    }

    private static func detail() throws -> OnRampAssetDetail {
        let json = #"""
        {
            "assetId":"ton/usdt","symbol":"USDT","decimals":6,"stablecoin":true,"extraIdRequired":false,
            "paymentMethods":[
                {"type":"card","name":"Card","image":"","isP2P":false,"providers":[
                    {"merchantId":"mercuryo","fiat":"USD"},
                    {"merchantId":"transak","fiat":"USD"},
                    {"merchantId":"transak","fiat":"EUR"}
                ]},
                {"type":"apple_pay","name":"Apple Pay","image":"","isP2P":false,"providers":[
                    {"merchantId":"mercuryo","fiat":"USD"}
                ]},
                {"type":"bank_transfer","name":"Bank transfer","image":"","isP2P":false,"providers":[
                    {"merchantId":"transak","fiat":"USD"}
                ]},
                {"type":"p2p","name":"P2P Express","image":"","isP2P":true,"providers":[
                    {"merchantId":"p2p","fiat":"USD"},
                    {"merchantId":"p2p","fiat":"EUR"}
                ]}
            ]
        }
        """#
        return try JSONDecoder().decode(OnRampAssetDetail.self, from: Data(json.utf8))
    }

    private static func merchants() throws -> [OnRampMerchantInfo] {
        let json = #"""
        [
            {"id":"mercuryo","title":"Mercuryo","description":"","image":"https://example.com/mercuryo.png","fee":0,"isP2P":false,"buttons":[]},
            {"id":"transak","title":"Transak","description":"","image":"https://example.com/transak.png","fee":0,"isP2P":false,"buttons":[]},
            {"id":"p2p","title":"P2P","description":"","image":"","fee":0,"isP2P":true,"buttons":[]}
        ]
        """#
        return try JSONDecoder().decode([OnRampMerchantInfo].self, from: Data(json.utf8))
    }
}

import Foundation
import KeeperCore
@testable import TKCore
import TKFeatureFlags
import TKKeychain
import XCTest

final class AnalyticsProviderTests: XCTestCase {
    func testLegacyLogEventKeyIncludesAnalyticsEventMobileNativeFields() throws {
        let (provider, service) = makeSubject()
        let eventKey = EventKey.deleteWallet
        let customKey = "source"
        let customValue = "test"

        provider.log(eventKey: eventKey, args: [customKey: customValue])

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(call.name, eventKey.key)
        XCTAssertEqual(call.args[customKey] as? String, customValue)
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.schemaVersion.rawValue] as? String,
            AnalyticsEventMobileNative().schemaVersion
        )
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.firebaseUserId.rawValue] as? String,
            TestData.uniqueDeviceId.uuidString
        )
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.platform.rawValue] as? String,
            AnalyticsEventMobileNative.Platform.iosNative.rawValue
        )
    }

    func testLegacyLogEventKeyPrefersArgsWhenTheyConflictWithAnalyticsEventMobileNative() throws {
        let (provider, service) = makeSubject()
        let schemaVersion = AnalyticsEventMobileNative.CodingKeys.schemaVersion.rawValue
        let firebaseUserId = AnalyticsEventMobileNative.CodingKeys.firebaseUserId.rawValue
        let platform = AnalyticsEventMobileNative.CodingKeys.platform.rawValue

        provider.log(
            eventKey: .deleteWallet,
            args: [
                schemaVersion: "override",
                firebaseUserId: "external-id",
            ]
        )

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(call.args[schemaVersion] as? String, "override")
        XCTAssertEqual(call.args[firebaseUserId] as? String, "external-id")
        XCTAssertEqual(
            call.args[platform] as? String,
            AnalyticsEventMobileNative.Platform.iosNative.rawValue
        )
    }

    func testLogEventKeyPrefersArgsWhenTheyConflictWithAnalyticsEventMobileNative() throws {
        let (provider, service) = makeSubject()
        let schemaVersion = AnalyticsEventMobileNative.CodingKeys.schemaVersion.rawValue
        let firebaseUserId = AnalyticsEventMobileNative.CodingKeys.firebaseUserId.rawValue
        let platform = AnalyticsEventMobileNative.CodingKeys.platform.rawValue

        provider.log(
            SendOpen(from: .deepLink)
                .withExtraValues(
                    [
                        schemaVersion: "override",
                        firebaseUserId: "external-id",
                    ]
                )
        )

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(call.args[schemaVersion] as? String, "override")
        XCTAssertEqual(call.args[firebaseUserId] as? String, "external-id")
        XCTAssertEqual(
            call.args[platform] as? String,
            AnalyticsEventMobileNative.Platform.iosNative.rawValue
        )
    }

    func testLogEncodableWithFeatureFlagsSendsEnabledOnesAsFlatOffSchemaFields() throws {
        let (provider, service) = makeSubject()

        let featureFlags: [FeatureFlag: Bool] = [.perpsEnabled: true, .swapKitEnabled: false]

        provider.log(LaunchApp().withExtraValues(featureFlags.analyticsParameters))

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(call.args["ff_ios_perps_enabled"] as? String, "true")
        XCTAssertNil(call.args["ff_ios_swapkit_enabled"])
    }

    func testLogEncodableIncludesAnalyticsEventMobileNativeFields() throws {
        let deviceId = "total-auth-device-id"
        let (provider, service) = makeSubject(deviceId: deviceId)

        let event = CustomError(
            severity: .warning,
            errorMessage: "tron_broken_address_detected"
        )

        provider.log(event)

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(call.name, event.eventName)
        XCTAssertEqual(call.args[CustomError.CodingKeys.errorMessage.rawValue] as? String, event.errorMessage)
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.schemaVersion.rawValue] as? String,
            AnalyticsEventMobileNative().schemaVersion
        )
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.firebaseUserId.rawValue] as? String,
            TestData.uniqueDeviceId.uuidString
        )
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.deviceId.rawValue] as? String,
            deviceId
        )
        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.platform.rawValue] as? String,
            AnalyticsEventMobileNative.Platform.iosNative.rawValue
        )
    }

    func testLogPrefillsUppercasedDeviceCountryCode() throws {
        let (provider, service) = makeSubject(deviceCountryCode: "us")

        provider.log(LaunchApp())

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.deviceCountryCode.rawValue] as? String,
            "US"
        )
    }

    func testLogPrefillsUppercasedKeysCountryCode() throws {
        let (provider, service) = makeSubject(keysCountryCode: "de")

        provider.log(LaunchApp())

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertEqual(
            call.args[AnalyticsEventMobileNative.CodingKeys.keysCountryCode.rawValue] as? String,
            "DE"
        )
    }

    func testLogOmitsKeysCountryCodeWhenSourceReturnsNil() throws {
        let (provider, service) = makeSubject()

        provider.log(LaunchApp())

        let call = try XCTUnwrap(service.calls.first)

        XCTAssertNil(call.args[AnalyticsEventMobileNative.CodingKeys.keysCountryCode.rawValue])
    }

    func testTaggedEventCarriesTheCampaignOfTheLinkThatOpenedTheFlow() throws {
        let (provider, service) = makeSubject()

        provider.log(
            eventKey: .storyOpen,
            utm: UtmParameters(link: "tonkeeper://staking?utm_source=newsletter&utm_campaign=autumn")
        )

        let call = try XCTUnwrap(service.calls.first)
        XCTAssertEqual(call.args[AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue] as? String, "newsletter")
        XCTAssertEqual(call.args[AnalyticsEventMobileNative.CodingKeys.utmCampaign.rawValue] as? String, "autumn")
        XCTAssertNil(call.args[AnalyticsEventMobileNative.CodingKeys.utmMedium.rawValue])
    }

    func testAnUntaggedEventCarriesNoCampaign() throws {
        let (provider, service) = makeSubject()

        provider.log(eventKey: .storyOpen)

        let call = try XCTUnwrap(service.calls.first)
        XCTAssertNil(call.args[AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue])
    }
}

private extension AnalyticsProviderTests {
    func makeSubject(
        deviceId: String? = nil,
        deviceCountryCode: String? = nil,
        keysCountryCode: String? = nil
    ) -> (AnalyticsProvider, AnalyticsServiceSpy) {
        let service = AnalyticsServiceSpy()
        let userDefaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
        let uniqueIdProvider = UniqueIdProvider(
            userDefaults: userDefaults,
            keychainVault: KeychainVaultMock(
                storedUUID: TestData.uniqueDeviceId
            )
        )

        let appInfoProvider = AppInfoProvider(
            userDefaults: userDefaults,
            storefrontCountryCodeCache: StorefrontCountryCodeCache()
        )
        if let deviceCountryCode {
            appInfoProvider.overrideDeviceCountryCode(deviceCountryCode)
        }

        let provider = AnalyticsProvider(
            analyticsServices: [service],
            uniqueIdProvider: uniqueIdProvider,
            deviceIdProvider: { deviceId },
            appInfoProvider: appInfoProvider,
            keysCountryCodeProvider: KeysCountryCodeProvider(countryCodeSource: { keysCountryCode })
        )

        return (provider, service)
    }
}

private enum TestData {
    static let uniqueDeviceId = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var calls = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        calls.append((name: name, args: args))
    }
}

private final class KeychainVaultMock: TKKeychainVault {
    private var storedData: Data?

    init(storedUUID: UUID) {
        storedData = try? JSONEncoder().encode(storedUUID)
    }

    func exists(query: TKKeychainQuery) throws -> Bool {
        storedData != nil
    }

    func biometricAccessState(query: TKKeychainQuery) -> TKKeychainBiometryAccess {
        storedData != nil ? .accessible : .missing
    }

    func get(query: TKKeychainQuery) throws -> Data {
        guard let storedData else {
            throw TKKeychainVaultError.unexpectedData
        }

        return storedData
    }

    func get(query: TKKeychainQuery) throws -> String {
        guard let storedData,
              let string = String(data: storedData, encoding: .utf8)
        else {
            throw TKKeychainVaultError.unexpectedData
        }

        return string
    }

    func get<T: Codable>(query: TKKeychainQuery) throws -> T {
        guard let storedData else {
            throw TKKeychainVaultError.unexpectedData
        }

        return try JSONDecoder().decode(T.self, from: storedData)
    }

    func set(_ value: Data, query: TKKeychainQuery) throws {
        storedData = value
    }

    func set(_ value: String, query: TKKeychainQuery) throws {
        storedData = value.data(using: .utf8)
    }

    func set<T: Codable>(_ value: T, query: TKKeychainQuery) throws {
        storedData = try JSONEncoder().encode(value)
    }

    func delete(_ query: TKKeychainQuery) throws {
        storedData = nil
    }
}

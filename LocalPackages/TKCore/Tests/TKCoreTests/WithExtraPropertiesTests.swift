@testable import TKCore
@testable import TKServices
import XCTest

final class WithExtraPropertiesTests: XCTestCase {
    func testWithExtraValuesAddsAllEncodedProperties() throws {
        let event = CustomError(
            severity: .warning,
            errorMessage: "tron_broken_address_detected"
        )
        let affectedEmptyHistory = 1
        let affectedUnknownHistory = 2
        struct ExtraProperties: Encodable {
            let affectedEmptyHistory: Int
            let affectedUnknownHistory: Int

            enum CodingKeys: String, CodingKey {
                case affectedEmptyHistory = "affected_empty_history"
                case affectedUnknownHistory = "affected_unknown_history"
            }
        }
        let payload = ExtraProperties(
            affectedEmptyHistory: affectedEmptyHistory,
            affectedUnknownHistory: affectedUnknownHistory
        )
        let encodedEvent = event.withExtraValues(payload)

        let encoded = try encode(encodedEvent)

        XCTAssertEqual(encoded[CustomError.CodingKeys.eventName.rawValue] as? String, event.eventName)
        XCTAssertEqual(
            encoded[CustomError.CodingKeys.severity.rawValue] as? String,
            event.severity.rawValue
        )
        XCTAssertEqual(
            encoded[CustomError.CodingKeys.errorMessage.rawValue] as? String,
            event.errorMessage
        )
        XCTAssertEqual(
            encoded[ExtraProperties.CodingKeys.affectedEmptyHistory.rawValue] as? Int,
            payload.affectedEmptyHistory
        )
        XCTAssertEqual(
            encoded[ExtraProperties.CodingKeys.affectedUnknownHistory.rawValue] as? Int,
            payload.affectedUnknownHistory
        )
    }

    func testWithExtraValuesOverwritesBaseValuesWhenKeyConflicts() throws {
        let event = CustomError(
            severity: .warning,
            errorMessage: "base_message"
        )
        struct OverridingExtra: Encodable {
            let eventName: String
            let severity: String

            enum CodingKeys: CodingKey {
                case eventName
                case severity

                var stringValue: String {
                    switch self {
                    case .eventName:
                        CustomError.CodingKeys.eventName.rawValue
                    case .severity:
                        CustomError.CodingKeys.severity.rawValue
                    }
                }
            }
        }

        let override = OverridingExtra(
            eventName: "overridden_event",
            severity: "error"
        )
        let encodedEvent = event.withExtraValues(override)

        let encoded = try encode(encodedEvent)

        XCTAssertEqual(
            encoded[CustomError.CodingKeys.eventName.rawValue] as? String,
            override.eventName
        )
        XCTAssertEqual(
            encoded[CustomError.CodingKeys.severity.rawValue] as? String,
            override.severity
        )
        XCTAssertEqual(
            encoded[CustomError.CodingKeys.errorMessage.rawValue] as? String,
            event.errorMessage
        )
    }
}

private func encode(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)

    guard let dictionary = object as? [String: Any] else {
        XCTFail("Expected a dictionary payload.")
        return [:]
    }

    return dictionary
}

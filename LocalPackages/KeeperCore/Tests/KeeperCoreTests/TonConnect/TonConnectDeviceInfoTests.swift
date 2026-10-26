@testable import KeeperCore
import XCTest

final class TonConnectDeviceInfoTests: XCTestCase {
    func testAdvertisesSignMessageWhenSupported() throws {
        let deviceInfo = TonConnect.DeviceInfo(maxMessages: 255, appVersion: "1.0", isSignMessageSupported: true)

        let signMessage = try XCTUnwrap(feature(named: "SignMessage", in: deviceInfo))
        XCTAssertEqual(signMessage["maxMessages"] as? Int, 255)
    }

    func testOmitsSignMessageWhenUnsupported() throws {
        let deviceInfo = TonConnect.DeviceInfo(maxMessages: 4, appVersion: "1.0", isSignMessageSupported: false)

        XCTAssertNil(try feature(named: "SignMessage", in: deviceInfo))
        XCTAssertNotNil(try feature(named: "SendTransaction", in: deviceInfo))
    }

    private func feature(named name: String, in deviceInfo: TonConnect.DeviceInfo) throws -> [String: Any]? {
        let data = try JSONEncoder().encode(deviceInfo)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let features = try XCTUnwrap(object["features"] as? [Any])
        return features
            .compactMap { $0 as? [String: Any] }
            .first { $0["name"] as? String == name }
    }
}

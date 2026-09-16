@testable import App
import TKUIKit
import XCTest

final class MultichainSwapToastConfigurationTests: XCTestCase {
    func testErrorConfigurationUsesFourSecondDuration() {
        let configuration = ToastPresenter.Configuration(title: "Error")
            .withMultichainSwapErrorDuration()

        guard case let .duration(duration) = configuration.dismissRule else {
            return XCTFail("Expected a fixed toast duration")
        }

        XCTAssertEqual(duration, 4)
    }
}

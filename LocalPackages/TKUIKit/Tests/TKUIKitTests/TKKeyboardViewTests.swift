import TKLocalize
@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class TKKeyboardViewTests: XCTestCase {
    func testVoiceOverActivationTypesAndDeletes() throws {
        let keyboard = TKKeyboardView()
        var buttons: [TKKeyboardView.Button] = []
        keyboard.didTapButton = { buttons.append($0) }

        XCTAssertTrue(try XCTUnwrap(keyboard.control(labeled: "5")).accessibilityActivate())
        XCTAssertTrue(try XCTUnwrap(keyboard.control(labeled: TKLocales.Actions.delete)).accessibilityActivate())

        XCTAssertEqual(buttons, [.digit(5), .backspace])
    }

    func testANewTouchCommitsTheKeyStillHeldOnce() throws {
        let keyboard = TKKeyboardView()
        var buttons: [TKKeyboardView.Button] = []
        keyboard.didTapButton = { buttons.append($0) }
        let five = try XCTUnwrap(keyboard.control(labeled: "5"))
        let seven = try XCTUnwrap(keyboard.control(labeled: "7"))
        let delete = try XCTUnwrap(keyboard.control(labeled: TKLocales.Actions.delete))

        five.sendActions(for: .touchDown)
        delete.sendActions(for: .touchDown)
        delete.sendActions(for: .touchUpInside)
        five.sendActions(for: .touchDown)
        seven.sendActions(for: .touchDown)
        seven.sendActions(for: .touchUpInside)

        XCTAssertEqual(buttons, [.digit(5), .backspace, .digit(5), .digit(7)])
    }
}

private extension UIView {
    func control(labeled label: String) -> UIControl? {
        if let control = self as? UIControl, control.accessibilityLabel == label {
            return control
        }
        return subviews.lazy.compactMap { $0.control(labeled: label) }.first
    }
}

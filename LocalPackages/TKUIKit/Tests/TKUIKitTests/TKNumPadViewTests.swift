import TKLocalize
import TKTestSupport
@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class TKNumPadViewTests: XCTestCase {
    private var window: UIWindow!
    private var field: UITextField!
    private var numPad: TKNumPadView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        field = UITextField(frame: CGRect(x: 0, y: 100, width: 390, height: 44))
        numPad = TKNumPadView(textField: field)
        field.inputView = numPad
        window.addSubview(field)
        window.makeKeyAndVisible()
        field.becomeFirstResponder()
    }

    override func tearDown() {
        field.resignFirstResponder()
        window = nil
        field = nil
        numPad = nil
        super.tearDown()
    }

    func testKeysEditTheFieldThroughItsDelegate() throws {
        let delegate = RejectingDelegate(rejected: "0")
        field.delegate = delegate

        for digit in ["1", "0", "5"] {
            try numPad.key(digit).sendActions(for: .touchUpInside)
        }
        XCTAssertEqual(field.text, "15")

        let delete = try numPad.key(TKLocales.Actions.delete)
        delete.sendActions(for: .touchDown)
        delete.sendActions(for: .touchUpInside)
        XCTAssertEqual(field.text, "1")
    }

    func testKeysOfAnArabicSystemShowItsDigitsAndTypeWesternOnes() throws {
        let pad = TKNumPadView(textField: field, locale: Locale(identifier: "ar_SA"))
        let key = try pad.key("7")

        XCTAssertEqual(key.subviews.compactMap { ($0 as? UILabel)?.text }, ["\u{0667}"])
        key.sendActions(for: .touchUpInside)
        XCTAssertEqual(field.text, "7")
    }

    func testVoiceOverActivationTypesAndDeletes() throws {
        XCTAssertTrue(try numPad.key("7").accessibilityActivate())
        XCTAssertTrue(try numPad.key("8").accessibilityActivate())
        XCTAssertEqual(field.text, "78")

        XCTAssertTrue(try numPad.key(TKLocales.Actions.delete).accessibilityActivate())
        XCTAssertEqual(field.text, "7")
    }

    func testPresetsAddAChipRowThatRunsTheirActions() throws {
        let pad = TKNumPadView(textField: field)
        let heightWithoutPresets = pad.frame.height
        var tapped: [String] = []

        pad.presets = ["25%", "MAX"].map { title in TKNumPadPreset(title: title) { tapped.append(title) } }

        XCTAssertEqual(pad.frame.height, heightWithoutPresets + TKActionButtonSize.small.height + 16)
        try XCTUnwrap(pad.chip("MAX")).sendActions(for: .touchUpInside)
        XCTAssertEqual(tapped, ["MAX"])

        pad.presets = []
        XCTAssertEqual(pad.frame.height, heightWithoutPresets)
        XCTAssertNil(pad.chip("MAX"))
    }

    func testButtonAddsTheActionRowAndRunsItsAction() throws {
        let pad = TKNumPadView(textField: field)
        let heightWithoutButton = pad.frame.height
        var taps = 0

        pad.button = TKNumPadButton(title: "Continue") { taps += 1 }
        XCTAssertEqual(pad.frame.height, heightWithoutButton - 72 + 24 + TKActionButtonSize.large.height + 29)
        try XCTUnwrap(pad.chip("Continue")).sendActions(for: .touchUpInside)
        XCTAssertEqual(taps, 1)

        pad.button = TKNumPadButton(title: "Minimum amount €20", isEnabled: false) { taps += 1 }
        XCTAssertFalse(try XCTUnwrap(pad.chip("Minimum amount €20")).isEnabled)
        XCTAssertNil(pad.chip("Continue"))

        pad.button = nil
        XCTAssertEqual(pad.frame.height, heightWithoutButton)
    }

    func testTouchesBetweenAndBesideKeysReachTheNearestKey() throws {
        let pad = TKNumPadView(textField: field)
        pad.frame.size.width = 390
        pad.layoutIfNeeded()
        let one = try pad.key("1")
        let delete = try pad.key(TKLocales.Actions.delete)
        let oneFrame = pad.convert(one.bounds, from: one)
        let deleteFrame = pad.convert(delete.bounds, from: delete)

        XCTAssertTrue(pad.hitTest(CGPoint(x: oneFrame.maxX + 2, y: oneFrame.midY), with: nil) === one)
        XCTAssertTrue(pad.hitTest(CGPoint(x: deleteFrame.maxX + 10, y: deleteFrame.midY), with: nil) === delete)
        XCTAssertFalse(pad.hitTest(CGPoint(x: deleteFrame.midX, y: pad.bounds.maxY - 10), with: nil) is UIControl)
    }

    func testTextFieldGetsTheNumPadOnlyWhileTheFlagIsOn() {
        let textField = UITextField()
        defer { TKNumPadView.isEnabled = false }

        TKNumPadView.isEnabled = false
        textField.tkNumPadKeyboard()
        XCTAssertEqual(textField.keyboardType, .decimalPad)
        XCTAssertNil(textField.inputView)

        TKNumPadView.isEnabled = true
        textField.tkNumPadKeyboard()
        XCTAssertTrue(textField.inputView is TKNumPadView)
    }

    func testDeletingAfterAGroupSpaceDeletesTheDigitBeforeIt() throws {
        field.text = "1 234"
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 2))
        field.selectedTextRange = field.textRange(from: caret, to: caret)

        let delete = try numPad.key(TKLocales.Actions.delete)
        delete.sendActions(for: .touchDown)
        delete.sendActions(for: .touchUpInside)

        XCTAssertEqual(field.text, "234")
    }

    func testAmountControlDrawsItsDigitsOnlyWhileTheyFit() {
        TKNumPadView.isEnabled = true
        defer { TKNumPadView.isEnabled = false }
        let control = TKTextInputTextFieldControl()
        control.widthAnchor.constraint(equalToConstant: 60).isActive = true
        control.tkNumPadAmountKeyboard()
        let overlay = { control.subviews.first { $0 is SwiftUIHostingView } }

        control.inputText = "1234567890123"
        control.layoutIfNeeded()
        XCTAssertEqual(overlay()?.alpha, 0)
        XCTAssertNotEqual(control.textColor, .clear)

        control.inputText = "12"
        control.layoutIfNeeded()
        XCTAssertEqual(overlay()?.alpha, 1)
        XCTAssertEqual(control.textColor, .clear)

        control.inputText = ""
        control.layoutIfNeeded()
        XCTAssertEqual(overlay()?.alpha, 1)
        XCTAssertNotEqual(control.textColor, .clear)
    }

    func testAmountControlGroupsTheTextItsOwnerSets() {
        TKNumPadView.isEnabled = true
        defer { TKNumPadView.isEnabled = false }
        let control = TKTextInputTextFieldControl()

        control.tkNumPadAmountKeyboard()
        control.inputText = "1234567.5"

        XCTAssertTrue(control.inputView is TKNumPadView)
        XCTAssertEqual(control.text, "1 234 567.5")
    }

    func testKeysAreShorterOnScreensWithoutHomeIndicator() {
        XCTAssertEqual(TKNumPadView.keyHeight(screenHeight: 667), 40)
        XCTAssertEqual(TKNumPadView.keyHeight(screenHeight: 874), 48)
    }

    func testHoldingDeleteClearsTheField() async throws {
        let pad = TKNumPadView(textField: field, sleep: { _ in })
        field.text = "123456789"
        let delete = try pad.key(TKLocales.Actions.delete)

        delete.sendActions(for: .touchDown)
        XCTAssertEqual(field.text, "12345678")

        let changes = NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: field)
        await waitUntil(changes) { self.field.text?.isEmpty == true }
        delete.sendActions(for: .touchUpInside)
    }
}

private final class RejectingDelegate: NSObject, UITextFieldDelegate {
    let rejected: String

    init(rejected: String) {
        self.rejected = rejected
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        string != rejected
    }
}

private extension UIView {
    func key(_ label: String) throws -> UIControl {
        try XCTUnwrap(firstControl(labeled: label), "No key labeled \(label)")
    }

    func firstControl(labeled label: String) -> UIControl? {
        if let control = self as? UIControl, control.accessibilityLabel == label {
            return control
        }
        return subviews.lazy.compactMap { $0.firstControl(labeled: label) }.first
    }

    func chip(_ title: String) -> TKButton? {
        if let button = self as? TKButton, button.configuration.content.title == .plainString(title) {
            return button
        }
        return subviews.lazy.compactMap { $0.chip(title) }.first
    }
}

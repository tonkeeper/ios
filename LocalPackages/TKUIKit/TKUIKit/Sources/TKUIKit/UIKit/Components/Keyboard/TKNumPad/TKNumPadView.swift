import SnapKit
import TKLocalize
import UIKit

public struct TKNumPadPreset {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public struct TKNumPadButton {
    public let title: String
    public let isEnabled: Bool
    public let action: () -> Void

    public init(title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
}

public extension UITextField {
    func tkNumPadKeyboard() {
        keyboardType = .decimalPad
        guard TKNumPadView.isEnabled else { return }
        inputView = TKNumPadView(textField: self)
    }
}

public final class TKNumPadView: UIView {
    public static var isEnabled = false

    public var presets: [TKNumPadPreset] = [] {
        didSet { updatePresets(oldTitles: oldValue.map(\.title)) }
    }

    public var button: TKNumPadButton? {
        didSet { updateButton(oldValue: oldValue) }
    }

    private weak var textField: UITextField?
    private let keyHeight: CGFloat
    private var keys: [Key] = []
    private let contentStackView = UIStackView()
    private let presetsStackView = UIStackView()
    private let keysStackView = UIStackView()
    private let actionButton = TKButton(configuration: .actionButtonConfiguration(category: .primary, size: .large))
    private let feedback = KeyboardKeyFeedback()
    private let deleteRepeat: KeyboardDeleteRepeat

    public init(
        textField: UITextField,
        locale: Locale = TKAmountDigits.systemLocale,
        sleep: @escaping @MainActor (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        let screen = UIScreen.main.bounds
        let keyHeight = Self.keyHeight(screenHeight: max(screen.width, screen.height))
        self.textField = textField
        self.keyHeight = keyHeight
        deleteRepeat = KeyboardDeleteRepeat(sleep: sleep)
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: 0,
            height: Layout.height(showsPresets: false, showsButton: false, keyHeight: keyHeight)
        ))
        backgroundColor = .Background.page
        setup(locale: locale)
    }

    static func keyHeight(screenHeight: CGFloat) -> CGFloat {
        screenHeight < Layout.compactScreenHeight ? Layout.compactKeyHeight : Layout.keyHeight
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            deleteRepeat.cancel()
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let view = super.hitTest(point, with: event) else { return nil }
        let keysArea = convert(keysStackView.bounds, from: keysStackView).insetBy(dx: -Layout.inset, dy: -Layout.inset)
        guard !(view is Key), keysArea.contains(point) else { return view }
        return keys.min {
            convert($0.bounds, from: $0).squaredDistance(to: point) < convert($1.bounds, from: $1).squaredDistance(to: point)
        }
    }
}

private extension TKNumPadView {
    func setup(locale: Locale) {
        let digitKey = { self.characterKey($0, locale: locale) }
        let rows = [
            ["1", "2", "3"].map(digitKey),
            ["4", "5", "6"].map(digitKey),
            ["7", "8", "9"].map(digitKey),
            [characterKey(TKAmountDigits.decimalSeparator, locale: locale, showsPlate: false), digitKey("0"), deleteKey()],
        ]
        keys = rows.flatMap { $0 }
        for rowKeys in rows {
            let row = UIStackView(arrangedSubviews: rowKeys)
            row.distribution = .fillEqually
            row.spacing = Layout.spacing
            keysStackView.addArrangedSubview(row)
        }
        keysStackView.axis = .vertical
        keysStackView.distribution = .fillEqually
        keysStackView.spacing = Layout.spacing

        presetsStackView.distribution = .fillEqually
        presetsStackView.spacing = Layout.spacing
        presetsStackView.isHidden = true

        actionButton.isHidden = true
        actionButton.configuration.action = { [weak self] in
            self?.button?.action()
        }

        contentStackView.axis = .vertical
        contentStackView.spacing = Layout.inset
        contentStackView.addArrangedSubview(presetsStackView)
        contentStackView.addArrangedSubview(keysStackView)
        contentStackView.addArrangedSubview(actionButton)
        contentStackView.setCustomSpacing(Layout.buttonTopSpacing, after: keysStackView)
        addSubview(contentStackView)

        contentStackView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self).inset(Layout.inset)
        }
        presetsStackView.snp.makeConstraints { make in
            make.height.equalTo(Layout.presetHeight)
        }
        keysStackView.snp.makeConstraints { make in
            make.height.equalTo(Layout.keysHeight(keyHeight: keyHeight))
        }
        actionButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.buttonHeight)
        }
    }

    func updatePresets(oldTitles: [String]) {
        let titles = presets.map(\.title)
        guard titles != oldTitles else { return }
        presetsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, title) in titles.enumerated() {
            presetsStackView.addArrangedSubview(presetButton(title: title, index: index))
        }
        presetsStackView.isHidden = titles.isEmpty
        guard titles.isEmpty != oldTitles.isEmpty else { return }
        updateHeight()
    }

    func updateButton(oldValue: TKNumPadButton?) {
        if let button, button.title != oldValue?.title || button.isEnabled != oldValue?.isEnabled {
            actionButton.configuration.content = TKButton.Configuration.Content(title: .plainString(button.title))
            actionButton.configuration.isEnabled = button.isEnabled
        }
        guard (button == nil) != (oldValue == nil) else { return }
        actionButton.isHidden = button == nil
        updateHeight()
    }

    func updateHeight() {
        frame.size.height = Layout.height(showsPresets: !presets.isEmpty, showsButton: button != nil, keyHeight: keyHeight)
        if textField?.isFirstResponder == true {
            textField?.reloadInputViews()
        }
    }

    func presetButton(title: String, index: Int) -> TKButton {
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
        configuration.content = TKButton.Configuration.Content(title: .plainString(title))
        configuration.action = { [weak self] in
            guard let self, presets.indices.contains(index) else { return }
            feedback.select()
            presets[index].action()
        }
        return TKButton(configuration: configuration)
    }

    func characterKey(_ character: String, locale: Locale, showsPlate: Bool = true) -> Key {
        let label = UILabel()
        label.attributedText = TKAmountDigits.keyTitle(character, locale: locale).withTextStyle(.num2, color: .Text.primary, alignment: .center)
        let key = Key(content: label, showsPlate: showsPlate)
        key.accessibilityLabel = character
        let id = ObjectIdentifier(key)
        key.addAction(UIAction { [weak self] _ in
            self?.feedback.press(id)
        }, for: .touchDown)
        key.addAction(UIAction { [weak self] _ in
            self?.feedback.release(id)
            self?.insert(character)
        }, for: .touchUpInside)
        key.addAction(UIAction { [weak self] _ in
            self?.feedback.cancel(id)
        }, for: [.touchUpOutside, .touchCancel, .touchDragExit])
        return key
    }

    func deleteKey() -> Key {
        let imageView = UIImageView(image: .TKUIKit.Icons.Size36.delete)
        imageView.tintColor = .Icon.primary
        let key = Key(content: imageView, showsPlate: false)
        key.accessibilityLabel = TKLocales.Actions.delete
        key.addAction(UIAction { [weak self] _ in
            self?.startDeleting()
        }, for: .touchDown)
        key.addAction(UIAction { [weak self] _ in
            self?.deleteRepeat.cancel()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        return key
    }

    func startDeleting() {
        deleteBackward()
        feedback.delete()
        deleteRepeat.start(
            onRepeat: { [weak self] in
                self?.deleteBackward()
                self?.feedback.select()
            },
            onClear: { [weak self] in
                self?.clearText()
                self?.feedback.select()
            }
        )
    }

    func insert(_ text: String) {
        guard let textField, let range = textField.selectedRange,
              textField.allowsChange(in: range, replacement: text)
        else { return }
        textField.insertText(text)
    }

    func deleteBackward() {
        guard let textField, let range = textField.backwardDeletionRange,
              textField.allowsChange(in: range, replacement: "")
        else { return }
        if range.length > 1 {
            textField.select(range)
        }
        textField.deleteBackward()
    }

    func clearText() {
        guard let textField, textField.hasText,
              textField.allowsChange(in: NSRange(location: 0, length: (textField.text ?? "").utf16.count), replacement: "")
        else { return }
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        textField.deleteBackward()
    }
}

private extension CGRect {
    func squaredDistance(to point: CGPoint) -> CGFloat {
        let dx = Swift.max(minX - point.x, 0, point.x - maxX)
        let dy = Swift.max(minY - point.y, 0, point.y - maxY)
        return dx * dx + dy * dy
    }
}

private extension UITextField {
    var selectedRange: NSRange? {
        guard let selection = selectedTextRange else { return nil }
        return NSRange(
            location: offset(from: beginningOfDocument, to: selection.start),
            length: offset(from: selection.start, to: selection.end)
        )
    }

    var backwardDeletionRange: NSRange? {
        guard let range = selectedRange else { return nil }
        guard range.length == 0 else { return range }
        guard range.location > 0 else { return nil }
        let text = (text ?? "") as NSString
        let previous = text.rangeOfComposedCharacterSequence(at: range.location - 1)
        guard previous.location > 0, text.substring(with: previous) == " " else { return previous }
        return NSUnionRange(text.rangeOfComposedCharacterSequence(at: previous.location - 1), previous)
    }

    func select(_ range: NSRange) {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length)
        else { return }
        selectedTextRange = textRange(from: start, to: end)
    }

    func allowsChange(in range: NSRange, replacement: String) -> Bool {
        guard let delegate else { return true }
        if #available(iOS 26.0, *),
           let allows = delegate.textField?(self, shouldChangeCharactersInRanges: [NSValue(range: range)], replacementString: replacement)
        {
            return allows
        }
        return delegate.textField?(self, shouldChangeCharactersIn: range, replacementString: replacement) ?? true
    }
}

private final class Key: UIControl {
    private let plateView = UIView()
    private let showsPlate: Bool

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            guard !isHighlighted else {
                plateView.layer.removeAllAnimations()
                updatePlate()
                return
            }
            UIView.animate(withDuration: Layout.releaseDuration, delay: 0, options: .allowUserInteraction) {
                self.updatePlate()
            }
        }
    }

    init(content: UIView, showsPlate: Bool) {
        self.showsPlate = showsPlate
        super.init(frame: .zero)

        isAccessibilityElement = true
        accessibilityTraits = [.button, .keyboardKey]

        plateView.isUserInteractionEnabled = false
        plateView.layer.cornerRadius = Layout.keyCornerRadius
        plateView.layer.cornerCurve = .continuous
        content.isUserInteractionEnabled = false
        addSubview(plateView)
        addSubview(content)

        plateView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        content.snp.makeConstraints { make in
            make.center.equalTo(self)
        }
        updatePlate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
        return true
    }

    private func updatePlate() {
        plateView.backgroundColor = isHighlighted ? .Background.contentTint : showsPlate ? .Background.content : .clear
    }
}

private enum Layout {
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 8
    static let keyHeight: CGFloat = 48
    static let compactKeyHeight: CGFloat = 40
    static let compactScreenHeight: CGFloat = 812
    static let keyCornerRadius: CGFloat = 16
    static let releaseDuration: TimeInterval = 0.2
    static let presetHeight = TKActionButtonSize.small.height
    static let bottomHeight: CGFloat = 72
    static let buttonHeight = TKActionButtonSize.large.height
    static let buttonTopSpacing: CGFloat = 24
    static let buttonBottomHeight: CGFloat = 29

    static func keysHeight(keyHeight: CGFloat) -> CGFloat {
        keyHeight * 4 + spacing * 3
    }

    static func height(showsPresets: Bool, showsButton: Bool, keyHeight: CGFloat) -> CGFloat {
        let bottom = showsButton ? buttonTopSpacing + buttonHeight + buttonBottomHeight : bottomHeight
        return inset + (showsPresets ? presetHeight + inset : 0) + keysHeight(keyHeight: keyHeight) + bottom
    }
}

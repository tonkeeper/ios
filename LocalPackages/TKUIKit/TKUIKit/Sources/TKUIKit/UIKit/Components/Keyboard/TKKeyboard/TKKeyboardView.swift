import TKLocalize
import UIKit

public final class TKKeyboardView: UIView {
    public enum Button: Hashable {
        case digit(Int)
        case backspace
        case biometry
    }

    public enum Biometry {
        case none
        case touchId
        case faceId

        var model: TKKeyboardButton.Model {
            switch self {
            case .faceId:
                return .image(.TKUIKit.Icons.Size36.faceid)
            case .touchId:
                return .image(.TKUIKit.Icons.Size36.fingerprint)
            case .none:
                return .none
            }
        }

        var accessibilityLabel: String? {
            switch self {
            case .faceId:
                return "Face ID"
            case .touchId:
                return "Touch ID"
            case .none:
                return nil
            }
        }

        var isUserInteractionEnable: Bool {
            switch self {
            case .faceId:
                return true
            case .touchId:
                return true
            case .none:
                return false
            }
        }
    }

    public var didTapButton: ((Button) -> Void)?

    public var biometry: Biometry = .none {
        didSet {
            buttons[.biometry]?.configure(model: biometry.model)
            buttons[.biometry]?.accessibilityLabel = biometry.accessibilityLabel
            buttons[.biometry]?.isUserInteractionEnabled = biometry.isUserInteractionEnable
        }
    }

    private var touchedDownKey: (button: TKKeyboardButton, type: Button)?

    private var buttons = [Button: TKKeyboardButton]()
    private let feedback = KeyboardKeyFeedback()
    private let deleteRepeat = KeyboardDeleteRepeat()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        return stackView
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
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
}

private extension TKKeyboardView {
    func setup() {
        addSubview(stackView)

        setupButtons()

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }

    func setupButtons() {
        let buttons = [
            [Button.digit(1), Button.digit(2), Button.digit(3)],
            [Button.digit(4), Button.digit(5), Button.digit(6)],
            [Button.digit(7), Button.digit(8), Button.digit(9)],
            [Button.biometry, Button.digit(0), Button.backspace],
        ]

        for row in buttons {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            for type in row {
                let button = createButton(type: type)
                self.buttons[type] = button
                rowStackView.addArrangedSubview(button)
            }
            stackView.addArrangedSubview(rowStackView)
        }
    }

    func createButton(type: Button) -> TKKeyboardButton {
        let button = TKKeyboardButton()

        switch type {
        case let .digit(digit):
            button.configure(model: .text("\(digit)"))
        case .backspace:
            button.configure(model: .image(.TKUIKit.Icons.Size36.delete))
            button.accessibilityLabel = TKLocales.Actions.delete
        case .biometry:
            button.configure(model: biometry.model)
            button.accessibilityLabel = biometry.accessibilityLabel
            button.isUserInteractionEnabled = biometry.isUserInteractionEnable
        }

        if type == .backspace {
            button.addAction(UIAction { [weak self] _ in
                self?.commitTouchedDownKey()
                self?.startDeleting()
            }, for: .touchDown)
            button.addAction(UIAction { [weak self] _ in
                self?.deleteRepeat.cancel()
            }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            return button
        }

        let id = ObjectIdentifier(button)
        button.addAction(UIAction(handler: { [weak self] _ in
            self?.feedback.press(id)
            self?.commitTouchedDownKey()
            self?.touchedDownKey = (button, type)
        }), for: .touchDown)

        button.addAction(UIAction(handler: { [weak self] _ in
            self?.feedback.release(id)
            self?.touchedDownKey = nil
            self?.didTapButton?(type)
        }), for: .touchUpInside)

        button.addAction(UIAction(handler: { [weak self] _ in
            self?.feedback.cancel(id)
            self?.touchedDownKey = nil
        }), for: [.touchDragExit, .touchCancel])

        return button
    }

    func commitTouchedDownKey() {
        guard let touchedDownKey else { return }
        self.touchedDownKey = nil
        touchedDownKey.button.cancelTracking(with: nil)
        feedback.cancel(ObjectIdentifier(touchedDownKey.button))
        didTapButton?(touchedDownKey.type)
    }

    func startDeleting() {
        didTapButton?(.backspace)
        feedback.delete()
        deleteRepeat.start(
            onRepeat: { [weak self] in self?.repeatDelete() },
            onClear: { [weak self] in self?.repeatDelete() }
        )
    }

    func repeatDelete() {
        didTapButton?(.backspace)
        feedback.select()
    }
}

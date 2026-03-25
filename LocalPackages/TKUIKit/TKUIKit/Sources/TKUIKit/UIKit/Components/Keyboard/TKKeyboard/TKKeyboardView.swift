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
            buttons[.biometry]?.isUserInteractionEnabled = biometry.isUserInteractionEnable
        }
    }

    private var touchedDownButton: TKKeyboardButton?

    private var buttons = [Button: TKKeyboardButton]()

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
        case .biometry:
            button.configure(model: biometry.model)
            button.isUserInteractionEnabled = biometry.isUserInteractionEnable
        }

        button.addAction(UIAction(handler: { [weak self] _ in
            if let touchedDownButton = self?.touchedDownButton {
                touchedDownButton.cancelTracking(with: nil)
                self?.didTapButton?(type)
            }
            self?.touchedDownButton = button
        }), for: .touchDown)

        button.addAction(UIAction(handler: { [weak self] _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self?.touchedDownButton = nil
            self?.didTapButton?(type)
        }), for: .touchUpInside)

        button.addAction(UIAction(handler: { [weak self] _ in
            self?.touchedDownButton = nil
        }), for: .touchDragExit)

        button.addAction(UIAction(handler: { [weak self] _ in
            self?.touchedDownButton = nil
        }), for: .touchCancel)

        return button
    }
}

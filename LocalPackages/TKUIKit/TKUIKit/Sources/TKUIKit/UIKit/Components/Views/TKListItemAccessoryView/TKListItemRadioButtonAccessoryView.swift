import UIKit

public final class TKListItemRadioButtonAccessoryView: UIControl {
    public struct Configuration {
        public let isSelected: Bool
        public let tintColors: [TKRadioButtonState: UIColor]
        public let size: CGFloat
        public let action: ((_ isSelected: Bool) -> Void)?

        public init(
            isSelected: Bool,
            tintColors: [TKRadioButtonState: UIColor] = [
                .selected: .Button.primaryBackground,
                .deselected: .Button.tertiaryBackground,
            ],
            size: CGFloat,
            action: ((_ isSelected: Bool) -> Void)?
        ) {
            self.isSelected = isSelected
            self.tintColors = tintColors
            self.size = size
            self.action = action
        }
    }

    public var configuration = Configuration(
        isSelected: false,
        tintColors: [:],
        size: .zero,
        action: nil
    ) {
        didSet {
            updateConfiguration()
            setNeedsLayout()
        }
    }

    private let radioButton = RadioButton()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let size = radioButton.sizeThatFits(size)
        return CGSize(width: size.width + 16, height: size.height)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let radioButtonSize = radioButton.sizeThatFits(bounds.size)
        radioButton.frame = CGRect(
            origin: CGPoint(x: 0, y: bounds.height / 2 - radioButtonSize.height / 2),
            size: radioButtonSize
        )
    }

    private func setup() {
        addSubview(radioButton)
        radioButton.isUserInteractionEnabled = false
        updateConfiguration()
    }

    private func updateConfiguration() {
        radioButton.isSelected = configuration.isSelected
        radioButton.tintColors = configuration.tintColors
        radioButton.size = configuration.size
        radioButton.didToggle = configuration.action
    }
}

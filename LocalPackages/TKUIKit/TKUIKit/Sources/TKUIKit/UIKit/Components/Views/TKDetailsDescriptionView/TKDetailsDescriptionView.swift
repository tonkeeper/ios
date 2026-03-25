import UIKit

public final class TKDetailsDescriptionView: UIView, ConfigurableView {
    private let contentContainer = UIView()
    private let buttonsContainer = UIView()
    private let textLabel = UILabel()
    private var buttons = [UIButton]()

    private var buttonsContainerHeight: CGFloat = 0
    private var heigth: CGFloat = 0

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public struct Model {
        public struct Button {
            public let text: String
            public let closure: (() -> Void)?

            public init(text: String, closure: (() -> Void)?) {
                self.text = text
                self.closure = closure
            }
        }

        public let title: String
        public let buttons: [Button]

        public init(title: String, buttons: [Button]) {
            self.title = title
            self.buttons = buttons
        }
    }

    public func configure(model: Model) {
        buttonsContainer.subviews.forEach { $0.removeFromSuperview() }
        buttons = []

        textLabel.attributedText = model.title.withTextStyle(
            .body1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )

        for buttonModel in model.buttons {
            let button = UIButton(type: .system)
            button.setAttributedTitle(
                buttonModel.text.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
                for: .normal
            )
            button.addAction(UIAction(handler: { _ in
                buttonModel.closure?()
            }), for: .touchUpInside)
            buttonsContainer.addSubview(button)
            buttons.append(button)
        }
        setNeedsLayout()
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: heigth)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let contentWidth = bounds.width - .contentPadding * 2

        let textLabelSize = textLabel.sizeThatFits(CGSize(width: contentWidth, height: 0))
        textLabel.frame.size = textLabelSize
        textLabel.frame.origin.x = 0
        textLabel.frame.origin.y = 0

        layoutButtons(width: contentWidth)

        buttonsContainer.frame = CGRect(
            x: 0,
            y: textLabel.frame.maxY + 8,
            width: contentWidth,
            height: buttonsContainerHeight
        )

        let contentHeight: CGFloat = textLabel.frame.height + (buttonsContainerHeight == 0 ? 0 : 8 + buttonsContainerHeight)
        contentContainer.frame = CGRect(x: .contentPadding, y: .contentPadding, width: contentWidth, height: contentHeight)
        heigth = contentHeight + .contentPadding * 2
        invalidateIntrinsicContentSize()
    }

    func layoutButtons(width: CGFloat) {
        var originX: CGFloat = 0
        var originY: CGFloat = 0

        for button in buttons {
            button.sizeToFit()
            if originX + button.frame.width + .buttonSpacing > width {
                originX = 0
                originY += .buttonHeight
            }

            button.frame.origin.x = originX
            button.frame.origin.y = originY

            originX += button.frame.width + .buttonSpacing
        }
        buttonsContainerHeight = originY + (buttons.isEmpty ? 0 : .buttonHeight)
    }
}

private extension TKDetailsDescriptionView {
    func setup() {
        addSubview(contentContainer)
        contentContainer.addSubview(buttonsContainer)
        contentContainer.addSubview(textLabel)

        textLabel.numberOfLines = 0
        backgroundColor = .Background.content
        layer.masksToBounds = true
        layer.cornerRadius = 16
    }
}

private extension CGFloat {
    static let buttonSpacing: CGFloat = 12
    static let buttonHeight: CGFloat = 24
    static let contentPadding: CGFloat = 16
}

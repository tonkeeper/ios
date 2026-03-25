import UIKit

public final class TKListItemButtonAccessoryView: UIControl {
    private enum Constants {
        static let inset: CGFloat = 16
    }

    public struct Configuration {
        let title: String
        let category: TKActionButtonCategory
        let isEnable: Bool
        let action: (() -> Void)?

        public init(
            title: String,
            category: TKActionButtonCategory,
            isEnable: Bool = true,
            action: (() -> Void)?
        ) {
            self.title = title
            self.category = category
            self.isEnable = isEnable
            self.action = action
        }
    }

    private let button = TKButton()

    public var configuration: Configuration = .init(
        title: "",
        category: .primary,
        isEnable: true,
        action: nil
    ) {
        didSet {
            updateConfiguration()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(button)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let fittingSize = button.sizeThatFits(.zero)
        button.frame = CGRect(x: 0, y: 0, width: fittingSize.width, height: bounds.height)
    }

    private func updateConfiguration() {
        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: configuration.category,
            size: .small
        )
        buttonConfiguration.isEnabled = configuration.isEnable
        buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(configuration.title))
        buttonConfiguration.action = configuration.action

        button.configuration = buttonConfiguration
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let fittingSize = button.sizeThatFits(.zero)
        return CGSize(width: fittingSize.width + Constants.inset, height: fittingSize.height)
    }

    override public var intrinsicContentSize: CGSize {
        let fittingSize = button.sizeThatFits(.zero)
        return CGSize(width: fittingSize.width + Constants.inset, height: fittingSize.height)
    }
}

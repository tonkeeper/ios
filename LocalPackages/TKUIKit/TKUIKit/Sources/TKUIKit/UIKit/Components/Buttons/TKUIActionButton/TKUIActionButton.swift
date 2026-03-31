import UIKit

public final class TKUIActionButton: TKUIButton<TKUIButtonTitleIconContentView, TKUIButtonDefaultBackgroundView> {
    private let category: TKUIActionButtonCategory
    private let size: TKUIActionButtonSize

    public init(category: TKUIActionButtonCategory, size: TKUIActionButtonSize) {
        self.category = category
        self.size = size
        super.init(
            contentView: TKUIButtonTitleIconContentView(
                textStyle: size.textStyle,
                foregroundColor: category.titleColor
            ),
            backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: size.cornerRadius),
            contentHorizontalPadding: size.padding.left
        )
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override public func setupButtonState() {
        switch buttonState {
        case .disabled:
            backgroundView.setBackgroundColor(category.disabledBackgroundColor)
            buttonContentView.setForegroundColor(category.disabledTitleColor)
        case .highlighted:
            backgroundView.setBackgroundColor(category.highlightedBackgroundColor)
            buttonContentView.setForegroundColor(category.titleColor)
        case .normal:
            backgroundView.setBackgroundColor(category.backgroundColor)
            buttonContentView.setForegroundColor(category.titleColor)
        case .selected:
            break
        }
    }

    override public var loaderSize: TKLoaderView.Size {
        size.loaderSize
    }
}

private extension TKUIActionButtonSize {
    var loaderSize: TKLoaderView.Size {
        switch self {
        case .small:
            return .small
        case .medium:
            return .medium
        case .large:
            return .medium
        }
    }
}

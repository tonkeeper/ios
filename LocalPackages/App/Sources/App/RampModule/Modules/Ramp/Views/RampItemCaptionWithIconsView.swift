import TKUIKit
import UIKit

final class RampItemCaptionWithIconsView: UIView {
    struct Configuration: Hashable {
        let text: String
        let iconURLs: [URL]
    }

    private let label = UILabel()
    private let overlappingIconsView = OverlappingIconsView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(label)
        addSubview(overlappingIconsView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Configuration) {
        label.attributedText = model.text.withTextStyle(.body2, color: .Text.secondary)
        overlappingIconsView.configure(model: .init(iconURLs: model.iconURLs))
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = label.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let labelWidth = min(labelSize.width, bounds.width)
        let widthForIcons = bounds.width - labelWidth - Constants.spacing

        let iconsSize = overlappingIconsView.sizeThatFits(CGSize(width: widthForIcons, height: 0))
        let hasIcons = iconsSize.width > 0
        let iconsStartX = labelWidth + (hasIcons ? Constants.spacing : 0)

        let labelY = (bounds.height - labelSize.height) / 2
        label.frame = CGRect(x: 0, y: labelY, width: labelWidth, height: labelSize.height)

        overlappingIconsView.frame = CGRect(
            x: iconsStartX,
            y: (bounds.height - iconsSize.height) / 2,
            width: widthForIcons,
            height: iconsSize.height
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard size.width > 0 else { return .zero }

        let labelSize = label.sizeThatFits(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let labelWidth = min(labelSize.width, size.width)
        let widthForIcons = size.width - labelWidth - Constants.spacing

        let iconsSize = overlappingIconsView.sizeThatFits(CGSize(width: widthForIcons, height: 0))
        let height = max(labelSize.height, iconsSize.height)

        return CGSize(width: size.width, height: height)
    }

    func prepareForReuse() {
        overlappingIconsView.prepareForReuse()
    }
}

private extension RampItemCaptionWithIconsView {
    enum Constants {
        static let spacing: CGFloat = 5
    }
}

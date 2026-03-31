import TKUIKit
import UIKit

final class OverlappingIconsView: UIView {
    struct Configuration {
        var iconURLs: [URL] = []
    }

    var configuration = Configuration() {
        didSet {
            applyIconURLsToViews()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let iconViews: [TKOutsideBorderImageView] = (0 ..< 3).map { _ in TKOutsideBorderImageView() }
    private let ellipsesImageView = TKImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(ellipsesImageView)
        iconViews.reversed().forEach { addSubview($0) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Configuration) {
        configuration = model
    }

    static func maxWidth(forIconCount count: Int) -> CGFloat {
        let totalSlots = min(3, count) + (count > 3 ? 1 : 0)
        guard totalSlots > 0 else { return 0 }
        let iconWidth = Constants.iconSize.width + Constants.borderWidth * 2
        return iconWidth + CGFloat(totalSlots - 1) * (iconWidth - Constants.overlap)
    }

    private func visibleIconCount(availableWidth: CGFloat) -> (visibleURLCount: Int, showEllipsis: Bool) {
        let maxURLIcons = min(3, configuration.iconURLs.count)
        let showEllipsis = configuration.iconURLs.count > 3
        let totalSlots = maxURLIcons + (showEllipsis ? 1 : 0)
        guard totalSlots > 0, availableWidth >= minWidthForTwoSlots else { return (0, false) }

        for n in (0 ... totalSlots).reversed() {
            let needWidth = n > 0 ? iconDimension + CGFloat(n - 1) * step : 0
            if availableWidth >= needWidth {
                if showEllipsis {
                    let urlCount = n > 0 ? min(3, n - 1) : 0
                    if urlCount == 0 {
                        return (0, false)
                    }
                    return (urlCount, n > 0)
                } else {
                    return (min(n, maxURLIcons), false)
                }
            }
        }
        return (0, false)
    }

    private func applyIconURLsToViews() {
        for i in 0 ..< min(3, configuration.iconURLs.count) {
            let url = configuration.iconURLs[i]
            iconViews[i].configuration = TKOutsideBorderImageView.Configuration(
                image: .urlImage(url),
                imageSize: Constants.iconSize,
                borderWidth: Constants.borderWidth,
                borderColor: .Background.content
            )
        }
        for i in min(3, configuration.iconURLs.count) ..< 3 {
            iconViews[i].prepareForReuse()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = bounds.width
        let (visibleURLCount, showEllipsis) = visibleIconCount(availableWidth: availableWidth)

        guard visibleURLCount > 0 || showEllipsis else {
            iconViews.forEach { $0.isHidden = true }
            ellipsesImageView.isHidden = true
            return
        }

        let iconY = (bounds.height - iconDimension) / 2
        var x: CGFloat = 0

        for i in 0 ..< visibleURLCount {
            iconViews[i].isHidden = false
            iconViews[i].frame = CGRect(x: x, y: iconY, width: iconDimension, height: iconDimension)
            x += step
        }
        for i in visibleURLCount ..< 3 {
            iconViews[i].isHidden = true
        }

        if showEllipsis {
            ellipsesImageView.configure(model: TKImageView.Model(
                image: .image(.TKUIKit.Icons.Size16.ellipses),
                tintColor: .Icon.secondary,
                size: .size(CGSize(width: 10, height: 10)),
                corners: .circle
            ))
            ellipsesImageView.isHidden = false
            ellipsesImageView.frame = CGRect(
                x: x + Constants.borderWidth,
                y: iconY + Constants.borderWidth,
                width: Constants.iconSize.width,
                height: Constants.iconSize.height
            )
            ellipsesImageView.backgroundColor = .Background.contentTint
        } else {
            ellipsesImageView.isHidden = true
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let totalCount = configuration.iconURLs.count + (configuration.iconURLs.count > 3 ? 1 : 0)
        guard totalCount > 0, size.width >= iconDimension else { return .zero }

        let (visibleURLCount, showEllipsis) = visibleIconCount(availableWidth: size.width)
        let totalVisible = visibleURLCount + (showEllipsis ? 1 : 0)
        guard totalVisible > 0 else { return .zero }

        let width = iconDimension + CGFloat(totalVisible - 1) * step
        return CGSize(width: width, height: Constants.iconSize.height)
    }

    override var intrinsicContentSize: CGSize {
        let width = configuration.iconURLs.isEmpty ? 0 : OverlappingIconsView.maxWidth(forIconCount: configuration.iconURLs.count)
        return CGSize(width: width, height: width > 0 ? Constants.iconSize.height : 0)
    }

    func prepareForReuse() {
        iconViews.forEach { $0.prepareForReuse() }
    }
}

private extension OverlappingIconsView {
    enum Constants {
        static let iconSize = CGSize(width: 18, height: 18)
        static let borderWidth: CGFloat = 2
        static let overlap: CGFloat = 6
    }

    var iconDimension: CGFloat {
        Constants.iconSize.width + Constants.borderWidth * 2
    }

    var step: CGFloat {
        iconDimension - Constants.overlap
    }

    var minWidthForTwoSlots: CGFloat {
        iconDimension + step
    }
}

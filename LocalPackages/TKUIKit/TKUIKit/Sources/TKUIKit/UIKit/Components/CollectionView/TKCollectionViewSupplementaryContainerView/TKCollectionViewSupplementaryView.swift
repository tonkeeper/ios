import UIKit

public protocol TKCollectionViewSupplementaryContainerViewContentView: ConfigurableView {
    func prepareForReuse()
}

public class TKCollectionViewSupplementaryContainerView<ContentView: TKCollectionViewSupplementaryContainerViewContentView>: UICollectionReusableView, ConfigurableView, ReusableView {
    public let contentView = ContentView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(model: ContentView.Model) {
        contentView.configure(model: model)
    }

    override public func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
        let cellContentViewSize = contentView.sizeThatFits(.init(width: targetSize.width, height: 0))
        let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        modifiedAttributes.frame.size = cellContentViewSize
        return modifiedAttributes
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        contentView.prepareForReuse()
    }
}

private extension TKCollectionViewSupplementaryContainerView {
    func setup() {
//    backgroundColor = .Background.page
        addSubview(contentView)
    }
}

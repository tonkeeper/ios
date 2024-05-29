import UIKit
import TKUIKit

public final class StakingInfoFooterView: UIView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
    public struct Model: Hashable {
        public let title: NSAttributedString?
        public init(title: String?) {
            self.title = title?.withTextStyle(.body3, color: .Text.tertiary, alignment: .left)
        }
    }
    
    public let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = .max
        return label
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 36)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let titleLabelSize = titleLabel.sizeThatFits(size)
        return CGSize(width: size.width, height: titleLabelSize.height)
    }
    
    public func prepareForReuse() {
        titleLabel.text = nil
    }
    
    public func configure(model: Model) {
        titleLabel.attributedText = model.title
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds
    }
}

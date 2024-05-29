import UIKit
import TKUIKit

final class SwapSettingsTitleSwicthView: UIView, ConfigurableView {
    var didSwitch: ((Bool) -> Void)?
    
    var padding: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16) {
        didSet {
            setNeedsLayout()
        }
    }
    
    lazy var titleView = UILabel()
    lazy var subtitleView = UILabel()
    lazy var swicthView = UISwitch()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        layer.cornerRadius = 16.0
        
        titleView.numberOfLines = 1
        titleView.lineBreakMode = .byTruncatingTail
        addSubview(titleView)
        
        subtitleView.numberOfLines = 2
        subtitleView.lineBreakMode = .byTruncatingTail
        addSubview(subtitleView)
        
        swicthView.onTintColor = .Accent.blue
        swicthView.addAction(.init(handler: { [weak self] _ in
            self?.didSwitch?(self?.swicthView.isOn == true)
        }), for: .valueChanged)
        addSubview(swicthView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(model: Model) {
        let titleText = model.title.withTextStyle(
            .label1,
            color: .Text.primary
        )
        titleView.attributedText = titleText
        
        let subtitleText = model.subtitle.withTextStyle(
            .body2,
            color: .Text.secondary
        )
        subtitleView.attributedText = subtitleText
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let swicthViewSize = swicthView.sizeThatFits(bounds.size)
        let swicthViewMinX = bounds.width - padding.right - swicthViewSize.width
        let swicthViewMinY = (bounds.height - swicthViewSize.height) / 2.0
        
        swicthView.frame = .init(
            x: swicthViewMinX,
            y: swicthViewMinY,
            width: swicthViewSize.width,
            height: swicthViewSize.height
        )
        
        let titleViewMinX = padding.left
        let titleViewMinY = padding.top
        
        let titleViewBounds = CGSize(
            width: bounds.width - titleViewMinX - swicthViewSize.width - 16.0,
            height: bounds.height
        )
        let titleViewSize = titleView.sizeThatFits(titleViewBounds)
        
        titleView.frame = .init(
            x: titleViewMinX,
            y: titleViewMinY,
            width: titleViewSize.width,
            height: titleViewSize.height
        )
        
        let subtitleViewBounds = CGSize(
            width: bounds.width - titleViewMinX - swicthViewSize.width - 16.0,
            height: bounds.height - padding.bottom - titleViewMinY - titleViewSize.height
        )
        let subtitleViewSize = subtitleView.sizeThatFits(subtitleViewBounds)
        let subtitleViewMinX = padding.left
        let subtitleViewMinY = titleViewMinY + titleViewSize.height

        subtitleView.frame = .init(
            x: subtitleViewMinX,
            y: subtitleViewMinY,
            width: subtitleViewSize.width,
            height: subtitleViewSize.height
        )
    }
}

extension SwapSettingsTitleSwicthView {
    struct Model {
        let title: String
        let subtitle: String
    }
}

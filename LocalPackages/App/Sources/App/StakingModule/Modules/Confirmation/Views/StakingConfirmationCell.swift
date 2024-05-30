import UIKit
import TKUIKit

final class StakingConfirmationCell: TKCollectionViewContainerCell<StakingConfirmationCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingConfirmationCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let contentView = TKListItemContentView()
    
    lazy var layout = TKListItemLayout(iconView: nil, contentView: contentView, valueView: nil)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout.layouSubviews(bounds: bounds)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layout.calculateSize(targetSize: size)
    }
    
    struct Model {
        let contentModel: TKListItemContentView.Model
        
        init(
            title: String,
            subtitle: String,
            description: String?
        ) {
            
            let leftView = TKListItemContentStackView.Model(
                titleSubtitleModel: TKListItemTitleSubtitleView.Model(
                    title: title.withTextStyle(
                        .body1,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    subtitle: nil
                ),
                description: nil
            )
            
            let rightView = TKListItemContentStackView.Model(
                titleSubtitleModel: TKListItemTitleSubtitleView.Model(
                    title: subtitle.withTextStyle(
                        .label1,
                        color: .Text.primary,
                        alignment: .right,
                        lineBreakMode: .byTruncatingTail
                    ),
                    subtitle: description?.withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .right,
                        lineBreakMode: .byTruncatingTail
                    )
                ),
                description: nil
            )
            
            self.contentModel = TKListItemContentView.Model(
                leftContentStackViewModel: leftView,
                rightContentStackViewModel: rightView
            )
        }
    }
    
    func configure(model: Model) {
        contentView.configure(model: model.contentModel)
    }
}

private extension StakingConfirmationCellContentView {
    func setup() {
        addSubview(contentView)
    }
}

import UIKit
import TKUIKit

final class StakingInfoCell: TKCollectionViewContainerCell<StakingInfoCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingInfoCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let contentView = TKUIListItemContentView()
    
    lazy var layout = TKListItemLayout(iconView: nil, contentView: contentView, valueView: nil)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(contentView)
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
        let contentModel: TKUIListItemContentView.Configuration
        
        init(
            title: String,
            description: String,
            tagModel: TKUITagView.Configuration?
        ) {
            
            let attributedTitle = title.withTextStyle(.body2, color: .Text.secondary, alignment: .left)
            let attributedDescription = description.withTextStyle(.body2, color: .Text.primary, alignment: .right)
            
            let leftView = TKUIListItemContentLeftItem.Configuration(
                title: attributedTitle,
                tagViewModel: tagModel,
                subtitle: nil,
                description: nil
            )
            
            let rightView = TKUIListItemContentRightItem.Configuration(
                value: attributedDescription,
                subtitle: nil,
                description: nil
            )
            
            let contentModel = TKUIListItemContentView.Configuration(
                leftItemConfiguration: leftView,
                rightItemConfiguration: rightView
            )
            
            self.contentModel = contentModel
        }
    }
    
    func configure(model: Model) {
        contentView.configure(configuration: model.contentModel)
    }
}

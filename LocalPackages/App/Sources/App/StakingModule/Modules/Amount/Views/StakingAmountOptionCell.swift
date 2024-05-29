import TKUIKit
import UIKit

final class StakingAmountOptionCell: TKCollectionViewContainerCell<StakingAmountOptionCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingAmountOptionCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let iconView = TKListItemIconImageView()
    let contentView = TKUIListItemContentView()
    
    let switchView: TKButton = {
        let v = TKButton()
        v.configuration = .init(
            content: .init(icon: .TKUIKit.Icons.Size16.switch),
            iconTintColor: .Text.tertiary
        )
        return v
    }()
    
    lazy var layout = TKListItemLayout(iconView: iconView, contentView: contentView, valueView: switchView)
    
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
        let iconViewSize = iconView.bounds
        iconView.layer.cornerRadius = min(iconViewSize.height, iconViewSize.width) / 2.0
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layout.calculateSize(targetSize: size)
    }
    
    struct Model {
        let iconModel: TKListItemIconImageView.Model
        let contentModel: TKUIListItemContentView.Configuration
        
        init(
            iconModel: TKListItemIconImageView.Model,
            title: String,
            subtitle: String,
            tagModel: TKUITagView.Configuration?
        ) {
            self.iconModel = iconModel
            
            let attributedTitle = title.withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            
            let attributedSubtitle = subtitle.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            
            let leftView = TKUIListItemContentLeftItem.Configuration(
                title: attributedTitle,
                tagViewModel: tagModel,
                subtitle: attributedSubtitle,
                description: nil
            )
            
            let contentModel = TKUIListItemContentView.Configuration(
                leftItemConfiguration: leftView,
                rightItemConfiguration: nil
            )
            
            self.contentModel = contentModel
        }
    }
    
    func configure(model: Model) {
        iconView.configure(model: model.iconModel)
        contentView.configure(configuration: model.contentModel)
    }
}

private extension StakingAmountOptionCellContentView {
    func setup() {
        iconView.clipsToBounds = true
        addSubview(iconView)
        addSubview(contentView)
        addSubview(switchView)
    }
}

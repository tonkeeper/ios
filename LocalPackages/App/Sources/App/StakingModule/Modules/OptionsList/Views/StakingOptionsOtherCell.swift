import UIKit
import TKUIKit

final class StakingOptionsOtherCell: TKCollectionViewContainerCell<StakingOptionsOtherCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        accessoryType = .disclosureIndicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingOptionsOtherCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let iconView = UIImageView()
    let contentView = TKUIListItemContentView()
    
    lazy var layout = TKListItemLayout(iconView: iconView, contentView: contentView, valueView: nil)
    
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
        let iconViewPosition = iconView.center
        let iconViewMinSide = min(iconViewSize.height, iconViewSize.width)
        iconView.frame.size = .init(width: iconViewMinSide, height: iconViewMinSide)
        iconView.center = iconViewPosition
        iconView.layer.cornerRadius = iconViewMinSide / 2.0
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layout.calculateSize(targetSize: size)
    }
    
    struct Model {
        let image: UIImage
        let contentModel: TKUIListItemContentView.Configuration
        
        init(
            image: UIImage,
            title: String,
            subtitle: String,
            description: String?,
            tagModel: TKUITagView.Configuration?
        ) {
            self.image = image
            
            let leftView = TKUIListItemContentLeftItem.Configuration(
                title: title.withTextStyle(
                    .label1,
                    color: .Text.primary,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                ),
                tagViewModel: tagModel,
                subtitle: subtitle.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                ),
                description: description?.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                )
            )
            
            self.contentModel = TKUIListItemContentView.Configuration(
                leftItemConfiguration: leftView,
                rightItemConfiguration: nil
            )
        }
    }
    
    func configure(model: Model) {
        iconView.image = model.image
        contentView.configure(configuration: model.contentModel)
    }
}

private extension StakingOptionsOtherCellContentView {
    func setup() {
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        addSubview(iconView)
        addSubview(contentView)
    }
}

import UIKit
import TKUIKit

final class StakingPoolsCell: TKCollectionViewContainerCell<StakingPoolsCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        accessoryType = .disclosureIndicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingPoolsCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let iconView = TKListItemIconImageView()
    let contentView = TKListItemContentView()
    let radioView = TKRadioView()
    
    lazy var layout = TKListItemLayout(iconView: iconView, contentView: contentView, valueView: radioView)
    
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
        let iconViewPosition = iconView.center
        let iconViewSize = iconView.bounds
        let iconViewMinSide = min(iconViewSize.height, iconViewSize.width)
        iconView.frame.size = .init(width: iconViewMinSide, height: iconViewMinSide)
        iconView.center = iconViewPosition
        iconView.layer.cornerRadius = iconViewMinSide / 2.0
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layout.calculateSize(targetSize: size)
    }
    
    struct Model {
        let iconModel: TKListItemIconImageView.Model
        let contentModel: TKListItemContentView.Model
        let isSelected: Bool
        
        init(
            iconModel: TKListItemIconImageView.Model,
            title: String,
            description: String,
            isSelected: Bool
        ) {
            self.iconModel = iconModel
            self.isSelected = isSelected
            
            let leftContentStackViewModel = TKListItemContentStackView.Model(
                titleSubtitleModel: TKListItemTitleSubtitleView.Model(
                    title: title.withTextStyle(
                        .label1, color: .Text.primary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    subtitle: nil
                ),
                description: description.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .left,
                    lineBreakMode: .byTruncatingTail
                )
            )
            
            self.contentModel = TKListItemContentView.Model(
                leftContentStackViewModel: leftContentStackViewModel,
                rightContentStackViewModel: nil
            )
        }
    }
    
    func configure(model: Model) {
        iconView.configure(model: model.iconModel)
        contentView.configure(model: model.contentModel)
        radioView.isSelected = model.isSelected
    }
}

private extension StakingPoolsCellContentView {
    func setup() {
        addSubview(iconView)
        addSubview(contentView)
        addSubview(radioView)
    }
}

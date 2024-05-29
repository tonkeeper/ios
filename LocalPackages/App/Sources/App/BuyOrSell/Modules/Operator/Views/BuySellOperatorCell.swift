import UIKit
import TKUIKit

final class BuySellOperatorCell: TKCollectionViewContainerCell<BuySellOperatorCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        cellContentView.radioView.isSelected = state.isSelected
    }
}

final class BuySellOperatorCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
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
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return layout.calculateSize(targetSize: size)
    }
    
    struct Model {
        let iconModel: TKListItemIconImageView.Model
        let contentModel: TKListItemContentView.Model
        
        init(
            iconModel: TKListItemIconImageView.Model,
            contentModel: TKListItemContentView.Model
        ) {
            self.iconModel = iconModel
            self.contentModel = contentModel
        }
    }
    
    func configure(model: Model) {
        iconView.configure(model: model.iconModel)
        contentView.configure(model: model.contentModel)
    }
}

private extension BuySellOperatorCellContentView {
    func setup() {
        addSubview(iconView)
        addSubview(contentView)
        addSubview(radioView)
    }
}

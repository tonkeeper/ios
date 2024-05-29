import UIKit
import TKUIKit

final class BuySellMethodCell: TKCollectionViewContainerCell<BuySellMethodCellContentView> {
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

final class BuySellMethodCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let radioView = TKRadioView()
    let contentView = TKListItemContentView()
    let chipsView = TKTokenChips()
    
    lazy var layout = TKListItemLayout(iconView: radioView, contentView: contentView, valueView: chipsView)
    
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
        let chipsModel: TKTokenChips.Model
        
        init(
            title: String,
            symbol: String? = nil,
            chipsModel: TKTokenChips.Model
        ) {
            let attributedText = NSMutableAttributedString()
            
            let attributedTitle = title.withTextStyle(.label1, color: .Text.primary)
            attributedText.append(attributedTitle)
            
            if let symbol {
                let attributedPoint = " · ".withTextStyle(.label1, color: .Text.secondary)
                let attributesSymbol = symbol.withTextStyle(.label1, color: .Text.primary)
                
                attributedText.append(attributedPoint)
                attributedText.append(attributesSymbol)
            }
            
            let leftView = TKListItemContentStackView.Model(
                titleSubtitleModel: .init(title: attributedText, subtitle: nil),
                description: nil
            )
            
            self.contentModel = .init(
                leftContentStackViewModel: leftView,
                rightContentStackViewModel: nil
            )
            
            self.chipsModel = chipsModel
        }
    }
    
    func configure(model: Model) {
        contentView.configure(model: model.contentModel)
        chipsView.configure(model: model.chipsModel)
    }
}

private extension BuySellMethodCellContentView {
    func setup() {
        addSubview(radioView)
        addSubview(contentView)
        addSubview(chipsView)
    }
}

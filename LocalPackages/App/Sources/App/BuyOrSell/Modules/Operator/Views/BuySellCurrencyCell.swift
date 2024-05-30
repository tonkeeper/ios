import UIKit
import TKUIKit

final class BuySellCurrencyCell: TKCollectionViewContainerCell<BuySellCurrencyCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class BuySellCurrencyCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let labelView = UILabel()
    let disclosureView: TKButton = {
        let v = TKButton()
        v.configuration = .init(
            content: .init(icon: .TKUIKit.Icons.Size16.switch),
            iconTintColor: .Icon.tertiary,
            isEnabled: false
        )
        return v
    }()
    
    lazy var layout = TKListItemLayout(iconView: nil, contentView: labelView, valueView: disclosureView)
    
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
        let attributedText: NSAttributedString
        
        init(
            title: String,
            description: String
        ) {
            let attributedTitle = title.withTextStyle(.label1, color: .Text.primary, alignment: .left)
            let attributedDescription = " \(description)".withTextStyle(.body1, color: .Text.secondary, alignment: .left)
            
            let attributedText = NSMutableAttributedString()
            attributedText.append(attributedTitle)
            attributedText.append(attributedDescription)
            self.attributedText = attributedText
        }
    }
    
    func configure(model: Model) {
        labelView.attributedText = model.attributedText
    }
}

private extension BuySellCurrencyCellContentView {
    func setup() {
        addSubview(labelView)
        addSubview(disclosureView)
    }
}

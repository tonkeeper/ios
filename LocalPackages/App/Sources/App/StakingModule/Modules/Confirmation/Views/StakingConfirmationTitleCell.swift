import UIKit
import TKUIKit

final class StakingConfirmationTitleCell: TKCollectionViewContainerCell<StakingConfirmationTitleCellContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isSeparatorEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StakingConfirmationTitleCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
    
    let iconView = UIImageView()
    let titleView = TKTitleDescriptionView(size: .big)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let iconViewMinX = (bounds.width - CGFloat.iconViewSize) / 2.0
        let iconViewMinY = 0.0
        
        iconView.frame = .init(
            x: iconViewMinX,
            y: iconViewMinY,
            width: CGFloat.iconViewSize,
            height: CGFloat.iconViewSize
        )
        iconView.layer.cornerRadius = CGFloat.iconViewSize / 2.0
        
        let titleViewSize = CGSize(width: bounds.width, height: 120 - .titleViewBottomPadding)
        let titleViewMinX = (bounds.width - titleViewSize.width) / 2.0
        let titleViewMinY = CGFloat.iconViewSize + .titleViewTopPadding
        
        titleView.frame = .init(
            x: titleViewMinX,
            y: titleViewMinY,
            width: titleViewSize.width,
            height: titleViewSize.height
        )
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let titleViewSize = titleView.bounds.size
        let height = CGFloat.iconViewSize + titleViewSize.height + .titleViewTopPadding
        return .init(width: bounds.width, height: height)
    }
    
    struct Model {
        let image: UIImage
        let titleModel: TKTitleDescriptionView.Model
        
        init(
            image: UIImage,
            title: String,
            topDescription: String,
            bottomDescription: String
        ) {
            self.image = image
            self.titleModel = .init(title: title, topDescription: topDescription, bottomDescription: bottomDescription)
        }
    }
    
    func configure(model: Model) {
        iconView.image = model.image
        titleView.configure(model: model.titleModel)
    }
}

private extension StakingConfirmationTitleCellContentView {
    func setup() {
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        addSubview(titleView)
    }
}

private extension CGFloat {
    static let iconViewSize = 96.0
    static let titleViewTopPadding = 20.0
    static let titleViewBottomPadding = 32.0
}

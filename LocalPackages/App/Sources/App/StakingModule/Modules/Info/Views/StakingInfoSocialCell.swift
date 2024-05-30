import UIKit
import TKUIKit

final class StakingInfoSocialCell: TKCollectionViewContainerCell<StakingInfoSocialCellContentView> {}

final class StakingInfoSocialCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
    var padding: UIEdgeInsets { .init(top: 0, left: 0, bottom: 0, right: 0) }
    
    let tokenView = TKTokenTagView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(tokenView)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        tokenView.frame = bounds
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        tokenView.sizeThatFits(size)
    }
    
    func configure(model: Model) {
        tokenView.configure(model: model.tokenModel)
        tokenView.removeAction(identifiedBy: Self.tokenViewActionIdentifier, for: .touchUpInside)
        tokenView.addAction(.init(identifier: Self.tokenViewActionIdentifier, handler: { _ in model.didSelect?() }), for: .touchUpInside)
    }
    
    private static var tokenViewActionIdentifier: UIAction.Identifier {
        .init(.init(describing: Self.self))
    }
}

extension StakingInfoSocialCellContentView {
    struct Model {
        let tokenModel: TKTokenTagView.Model
        let didSelect: (() -> Void)?
    }
}

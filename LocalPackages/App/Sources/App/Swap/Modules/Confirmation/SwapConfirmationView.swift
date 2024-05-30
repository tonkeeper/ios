import UIKit
import TKUIKit

final class SwapConfirmationView: UIView {
    lazy var navigationBarView: TKNavigationBarContainer = {
        let navigationBarView = TKNavigationBarContainer(barHeight: .navigationBarViewHeight)
        navigationBarView.barPadding = .init(top: 4, left: 16, bottom: 4, right: 16)
        navigationBarView.contentPadding = .zero
        navigationBarView.barViews = [titleView, closeButton]
        return navigationBarView
    }()
    
    lazy var closeButton: TKUIHeaderIconButton = {
        let v = TKUIHeaderIconButton()
        v.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )
        v.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return v
    }()
    
    lazy var titleView = UILabel()
    lazy var swapTokensView = SwapTokensContainerView()
    lazy var cancelButton = TKButton()
    lazy var confirmButton = TKButton()
    
    lazy var buttonsView: UIStackView = {
        let buttonsView = UIStackView()
        buttonsView.axis = .horizontal
        buttonsView.spacing = 16
        buttonsView.distribution = .fillEqually
        buttonsView.alignment = .fill
        return buttonsView
    }()
    
    lazy var successFlowView: TKSuccessFlowView = {
        let successFlowView = TKSuccessFlowView(
            contentView: buttonsView
        )
        return successFlowView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
                
        addSubview(navigationBarView)
        
        addSubview(swapTokensView)
        
        buttonsView.addArrangedSubview(cancelButton)
        buttonsView.addArrangedSubview(confirmButton)
        addSubview(successFlowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBarView.frame = .init(
            x: 0,
            y: 0,
            width: bounds.width,
            height: .navigationBarViewHeight
        )
        
        let swapTokensViewMinX = CGFloat.horizontalPadding
        let swapTokensViewMinY = navigationBarView.additionalInset
        let swapTokensViewSize = swapTokensView.sizeThatFits(bounds.size)
        
        swapTokensView.frame = .init(
            x: swapTokensViewMinX,
            y: swapTokensViewMinY,
            width: swapTokensViewSize.width - 2 * .horizontalPadding,
            height: swapTokensViewSize.height
        )
        
        let successFlowViewMinX = CGFloat.horizontalPadding
        let successFlowViewMinY = bounds.height - safeAreaInsets.bottom - .successFlowViewHeight - 16
        
        successFlowView.frame = .init(
            x: successFlowViewMinX,
            y: successFlowViewMinY,
            width: bounds.width - 2 * .horizontalPadding,
            height: .successFlowViewHeight
        )
    }
}

private extension CGFloat {
    static let navigationBarViewHeight: CGFloat = 48.0
    static let successFlowViewHeight: CGFloat = 64.0
    static let horizontalPadding: CGFloat = 16
}

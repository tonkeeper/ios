import UIKit
import TKUIKit

final class SwapInfoView: UIView {
    lazy var scrollView = UIScrollView()
    
    lazy var swapTokensView = SwapTokensContainerView()
    
    lazy var continueButton: TKButton = {
        let v = TKButton()
        v.configuration = .actionButtonConfiguration(category: .secondary, size: .large)
        v.configuration.content.title = .plainString("Enter Amount")
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        
        scrollView.addSubview(swapTokensView)
        scrollView.addSubview(continueButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
}

private extension SwapInfoView {
    func updateLayout(in bounds: CGSize) {
        scrollView.contentSize = .init(width: bounds.width, height: bounds.height - safeAreaInsets.top - safeAreaInsets.bottom)
        scrollView.frame = .init(x: 0, y: 0, width: bounds.width, height: bounds.height)
        
        let swapTokensViewSize = swapTokensView.sizeThatFits(bounds)
        
        swapTokensView.frame = .init(x: .horizontalPadding, y: 0, width: bounds.width - 2 * .horizontalPadding, height: swapTokensViewSize.height)
        
        let continueButtonWidth = bounds.width - 2 * .horizontalPadding
        let continueButtonHeight = 56.0
        let continueButtonMinY = swapTokensViewSize.height + 32
        let continueButtonMinX = CGFloat.horizontalPadding
        
        continueButton.frame = .init(x: continueButtonMinX, y: continueButtonMinY, width: continueButtonWidth, height: continueButtonHeight)
    }
}

private extension CGFloat {
    static let horizontalPadding: CGFloat = 16
}

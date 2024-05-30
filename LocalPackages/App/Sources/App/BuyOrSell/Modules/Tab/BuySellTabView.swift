import TKUIKit
import UIKit
import TKLocalize

enum BuySellTab: CaseIterable, CustomStringConvertible {
    case buy
    case sell
    
    var description: String {
        switch self {
        case .buy:
            return TKLocales.BuySell.Tabs.buyTab
        case .sell:
            return TKLocales.BuySell.Tabs.sellTab
        }
    }
}

final class BuySellTabView: UIView {
    lazy var tabView = TKTabView()

    lazy var currencyButton: TKButton = {
        let v = TKButton()
        v.configuration = .actionButtonConfiguration(category: .secondary, size: .small)
        v.configuration.content.title = .plainString("RU")
        v.configuration.cornerRadius = 16
        return v
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
        
    lazy var navigationBarView: TKNavigationBarContainer = {
        let navigationBarView = TKNavigationBarContainer(barHeight: 32)
        navigationBarView.barViews = [
            currencyButton,
            tabView,
            closeButton,
        ]
        return navigationBarView
    }()
    
    lazy var scrollView = UIScrollView()
    
    let buyViewControllerContainer = UIView()
    let sellViewControllerContainer = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        addSubview(scrollView)
        
        scrollView.addSubview(buyViewControllerContainer)
        scrollView.addSubview(sellViewControllerContainer)
        
        navigationBarView.barPadding = .init(top: 11, left: 16, bottom: 11, right: 16)
        addSubview(navigationBarView)
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
            height: 64
        )
        
        let scrollViewContentWidth = CGFloat(BuySellTab.allCases.count) * bounds.width
        let scrollViewContentHeight = bounds.height - navigationBarView.additionalInset - safeAreaInsets.bottom
        
        scrollView.contentSize = .init(width: scrollViewContentWidth, height: scrollViewContentHeight)
        scrollView.frame = .init(x: 0, y: navigationBarView.additionalInset, width: bounds.width, height: scrollViewContentHeight)
        
        buyViewControllerContainer.frame = .init(
            x: 0.0,
            y: 0,
            width: bounds.width,
            height: scrollViewContentHeight
        )
        
        sellViewControllerContainer.frame = .init(
            x: bounds.width,
            y: 0,
            width: bounds.width,
            height: scrollViewContentHeight
        )
    }
}

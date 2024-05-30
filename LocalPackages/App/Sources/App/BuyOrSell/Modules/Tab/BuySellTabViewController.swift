import TKUIKit
import UIKit
import SnapKit

final class BuySellTabViewController: GenericViewViewController<BuySellTabView>, UIScrollViewDelegate {
    private let buyViewController: BuySellViewController
    private let sellViewController: BuySellViewController
    
    var didSelectBuyTab: (() -> Void)?
    var didSelectSellTab: (() -> Void)?
    
    var didTapClose: (() -> Void)?
    
    init(
        buyViewController: BuySellViewController,
        sellViewController: BuySellViewController
    ) {
        self.buyViewController = buyViewController
        self.sellViewController = sellViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setup()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset == .zero {
            didSelectBuyTab?()
        } else if scrollView.contentOffset == .init(x: customView.bounds.width, y: 0) {
            didSelectSellTab?()
        }
    }
}

private extension BuySellTabViewController {
    func setup() {
        addChild(buyViewController)
        customView.buyViewControllerContainer.addSubview(buyViewController.view)
        buyViewController.view.snp.makeConstraints { [customView] make in
            make.top.bottom.equalTo(customView.buyViewControllerContainer)
            make.left.right.equalTo(customView.buyViewControllerContainer).inset(16)
        }
        buyViewController.didMove(toParent: self)
        
        addChild(sellViewController)
        customView.sellViewControllerContainer.addSubview(sellViewController.view)
        sellViewController.view.snp.makeConstraints { [customView] make in
            make.top.bottom.equalTo(customView.sellViewControllerContainer)
            make.left.right.equalTo(customView.sellViewControllerContainer).inset(16)
        }
        sellViewController.didMove(toParent: self)
        
        customView.scrollView.delegate = self
        customView.tabView.scrollView = customView.scrollView
        customView.scrollView.setContentOffset(.zero, animated: false)
        
        customView.tabView.tabItems = [
            .init(item: BuySellTab.buy.description) { [weak self] in
                guard let self else { return }
                self.customView.scrollView.setContentOffset(.init(x: 0, y: 0), animated: true)
                self.didSelectBuyTab?()
            },
            .init(item: BuySellTab.sell.description) { [weak self] in
                guard let self else { return }
                self.customView.scrollView.setContentOffset(.init(x: self.customView.bounds.width, y: 0), animated: true)
                self.didSelectSellTab?()
            },
        ]
        
        customView.closeButton.addTapAction { [weak self] in
            self?.didTapClose?()
        }
    }
}

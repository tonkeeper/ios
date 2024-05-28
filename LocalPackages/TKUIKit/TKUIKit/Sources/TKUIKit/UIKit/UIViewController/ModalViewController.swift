import UIKit
import SnapKit

open class ModalViewController<View: UIView, NavigationBar: ModalNavigationBarView>: GenericViewViewController<View> {
  
  public let customNavigationBarView = NavigationBar()
  private var leftNavigationItemObserveToken: NSKeyValueObservation?
  private var rightNavigationItemObserveToken: NSKeyValueObservation?
  
  deinit {
    leftNavigationItemObserveToken = nil
    rightNavigationItemObserveToken = nil
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    setupNavigationBarView()
  }
  
  open func setupNavigationBarView() {
    navigationController?.setNavigationBarHidden(true, animated: false)
    
    customView.addSubview(customNavigationBarView)
    
    customNavigationBarView.snp.makeConstraints { make in
      make.left.right.top.equalTo(customView)
      make.height.equalTo(ModalNavigationBarView.defaultHeight)
    }
    
    setupNavigationItemObservation()
    
    updateLeftBarItem()
    updateRightBarItem()
  }
  
  private func setupNavigationItemObservation() {
    leftNavigationItemObserveToken = navigationItem.observe(\.leftBarButtonItem) { [weak self] item, _ in
      self?.updateLeftBarItem()
    }
    rightNavigationItemObserveToken = navigationItem.observe(\.rightBarButtonItem) { [weak self] item, _ in
      self?.updateRightBarItem()
    }
  }
  
  private func updateLeftBarItem() {
    guard let leftItem = navigationItem.leftBarButtonItem?.customView else { return }
    customNavigationBarView.setupLeftBarItem(configuration: .init(view: leftItem))
  }
  
  private func updateRightBarItem() {
    guard let rightItem = navigationItem.rightBarButtonItem?.customView else { return }
    customNavigationBarView.setupRightBarItem(configuration: .init(view: rightItem))
  }
}

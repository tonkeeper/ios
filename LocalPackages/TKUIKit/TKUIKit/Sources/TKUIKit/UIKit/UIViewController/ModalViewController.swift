import UIKit
import SnapKit

open class ModalViewController<View: UIView, NavigationBar: ModalNavigationBarView>: GenericViewViewController<View>, UIAdaptivePresentationControllerDelegate {
  
  public var didDismiss: (() -> Void)?
  
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
  
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    navigationController?.presentationController?.delegate = self
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
  
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    didDismiss?()
  }
}

private extension ModalViewController {
  func setupNavigationItemObservation() {
    leftNavigationItemObserveToken = navigationItem.observe(\.leftBarButtonItem) { [weak self] item, _ in
      self?.updateLeftBarItem()
    }
    rightNavigationItemObserveToken = navigationItem.observe(\.rightBarButtonItem) { [weak self] item, _ in
      self?.updateRightBarItem()
    }
  }
  
  func updateLeftBarItem() {
    guard let leftItem = navigationItem.leftBarButtonItem?.customView else { return }
    customNavigationBarView.setupLeftBarItem(configuration: .init(view: leftItem))
  }
  
  func updateRightBarItem() {
    guard let rightItem = navigationItem.rightBarButtonItem?.customView else { return }
    customNavigationBarView.setupRightBarItem(configuration: .init(view: rightItem))
  }
}

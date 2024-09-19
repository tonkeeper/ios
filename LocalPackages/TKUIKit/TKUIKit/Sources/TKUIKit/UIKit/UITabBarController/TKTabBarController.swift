import UIKit
import SnapKit

public final class TKTabBarController: UITabBarController {
  
  public var didLongPressTabBarItem: ((Int) -> Void)?
  
  public let blurView = TKBlurView()
  
  public init() {
    super.init(nibName: nil, bundle: nil)
    object_setClass(self.tabBar, TKTabBar.self)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    view.insertSubview(blurView, belowSubview: tabBar)
    
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(tabBar)
    }

    let longPressRecognizer = UILongPressGestureRecognizer(
      target: self,
      action: #selector(longPressHandler(_: ))
    )
    tabBar.addGestureRecognizer(longPressRecognizer)
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  @objc
  func longPressHandler(_ recognizer: UILongPressGestureRecognizer) {
    guard recognizer.state == .began,
    let tabBarItems = tabBar.items else { return }
    let location = recognizer.location(in: tabBar)
    for (index, item) in tabBarItems.enumerated() {
      guard let view = item.value(forKey: "view") as? UIView else { continue }
      guard view.frame.contains(location) else { continue }
      
      didLongPressTabBarItem?(index)
    }
  }
}

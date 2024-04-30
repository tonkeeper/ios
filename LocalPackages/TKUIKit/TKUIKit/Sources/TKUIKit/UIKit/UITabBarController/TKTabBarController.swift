import UIKit
import SnapKit

public final class TKTabBarController: UITabBarController {
  
  public var didLongPressTabBarItem: ((Int) -> Void)?
  
  private let blurView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    return blurView
  }()
  private let colorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.transparent
    return view
  }()
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    view.insertSubview(blurView, belowSubview: tabBar)
    view.insertSubview(colorView, aboveSubview: blurView)
    
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(tabBar)
    }
    
    colorView.snp.makeConstraints { make in
      make.edges.equalTo(tabBar)
    }
    
    let longPressRecognizer = UILongPressGestureRecognizer(
      target: self,
      action: #selector(longPressHandler(_: ))
    )
    tabBar.addGestureRecognizer(longPressRecognizer)
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

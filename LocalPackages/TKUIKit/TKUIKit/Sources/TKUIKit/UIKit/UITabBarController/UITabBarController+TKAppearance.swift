import UIKit

public extension UITabBarController {
  func configureAppearance(isSeparatorVisible: Bool = true) {
    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.titleTextAttributes = [.font: TKTextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.inactiveIcon]
    itemAppearance.normal.iconColor = .TabBar.inactiveIcon
    itemAppearance.selected.titleTextAttributes = [.font: TKTextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.activeIcon]
    itemAppearance.selected.iconColor = .TabBar.activeIcon
    
    func createTabBarAppearance() -> UITabBarAppearance {
      let appearance = UITabBarAppearance()
      appearance.configureWithTransparentBackground()
      appearance.stackedLayoutAppearance = itemAppearance
      return appearance
    }
   
    let tabBarAppearance = createTabBarAppearance()
    tabBarAppearance.shadowColor = isSeparatorVisible ? .Separator.common : .clear
    tabBar.standardAppearance = tabBarAppearance
    
    if #available(iOS 15.0, *) {
      let scrollEdgeAppearance = createTabBarAppearance()
      scrollEdgeAppearance.shadowColor = .clear
      tabBar.scrollEdgeAppearance = scrollEdgeAppearance
    }
  }
}

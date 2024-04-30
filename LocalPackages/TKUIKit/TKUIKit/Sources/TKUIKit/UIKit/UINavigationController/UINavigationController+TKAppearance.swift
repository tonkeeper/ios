import UIKit

public extension UINavigationController {
  func configureDefaultAppearance() {
    navigationBar.configureDefaultAppearance()
  }
  
  func configureTransparentAppearance() {
    navigationBar.configureTransparentAppearance()
  }
}

public extension UINavigationBar {
  func configureDefaultAppearance() {
    
    func createAppearance() -> UINavigationBarAppearance {
      let standartAppearance = UINavigationBarAppearance()
      standartAppearance.configureWithOpaqueBackground()
      standartAppearance.backgroundColor = .Background.page
      standartAppearance.titleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                                .font: TKTextStyle.h3.font]
      standartAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                                     .font: TKTextStyle.h1.font]
      return standartAppearance
    }
    
    let separatorAppearance = createAppearance()
    separatorAppearance.shadowColor = .Separator.common
    standardAppearance = separatorAppearance
  }
  
  func configureTransparentAppearance() {
    let navigationBarAppearance = UINavigationBarAppearance()
    navigationBarAppearance.configureWithTransparentBackground()
    
    standardAppearance = navigationBarAppearance
    compactAppearance = navigationBarAppearance
    if #available(iOS 15.0, *) {
      compactScrollEdgeAppearance = navigationBarAppearance
    }
  }
}

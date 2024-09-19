import UIKit
import TKUIKit
import SnapKit

final class LaunchScreenViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .Background.page
    
    let imageView = UIImageView()
    imageView.image = UIImage(resource: .icLogo128)
    imageView.contentMode = .center
    imageView.tintColor = .Accent.blue
    
    view.addSubview(imageView)
    
    imageView.snp.makeConstraints { make in
      make.centerY.equalTo(view).offset(10)
      make.centerX.equalTo(view)
    }
  }
}

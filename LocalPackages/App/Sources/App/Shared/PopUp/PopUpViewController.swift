import UIKit
import TKUIKit

extension PopUp {
  final class ViewController: UIViewController, TKBottomSheetScrollContentViewController {
    var configuration: PopUp.Configuration? {
      didSet {
        didUpdateConfiguration()
      }
    }
    
    let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    var didUpdateHeight: (() -> Void)?
    
    var headerItem: TKPullCardHeaderItem?
    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
      contentStackView.systemLayoutSizeFitting(
        CGSize(width: width, height: 0),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
      ).height
    }
    
    override func viewDidLoad() {
      super.viewDidLoad()
      
      setup()
      didUpdateConfiguration()
    }
    
    private func didUpdateConfiguration() {
      contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      guard let configuration else { return }
      for item in configuration.items {
        let view = item.getView()
        contentStackView.addArrangedSubview(view)
        contentStackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(item.bottomSpace)))
      }
    }
    
    private func setup() {
      view.backgroundColor = .Background.page
      
      contentStackView.axis = .vertical
      
      view.addSubview(scrollView)
      scrollView.addSubview(contentStackView)
      
      scrollView.snp.makeConstraints { make in
        make.edges.equalTo(self.view)
      }
      contentStackView.snp.makeConstraints { make in
        make.edges.width.equalTo(scrollView)
      }
    }
  }
}

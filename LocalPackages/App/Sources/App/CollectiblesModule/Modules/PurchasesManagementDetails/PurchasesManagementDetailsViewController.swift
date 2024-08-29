import UIKit
import TKUIKit

final class PurchasesManagementDetailsViewController: UIViewController, TKBottomSheetScrollContentViewController {
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: .title(title: configuration.title, subtitle: nil))
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    stackView.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
  
  struct Configuration {
    let title: String
    let listConfiguration: TKListContainerView.Configuration
    let buttonConfiguration: TKButton.Configuration
  }
  
  private let listContainerView = TKListContainerView()
  private let button = TKButton()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let scrollView = UIScrollView()
  
  private let configuration: Configuration
  
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    listContainerView.configuration = configuration.listConfiguration
    button.configuration = configuration.buttonConfiguration
  }
  
  private func setup() {
    view.addSubview(scrollView)
    scrollView.addSubview(stackView)
    stackView.addArrangedSubview(listContainerView)
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(16)))
    stackView.addArrangedSubview(button)
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(16)))
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    
    stackView.snp.makeConstraints { make in
      make.width.equalTo(scrollView).offset(-32)
      make.left.right.equalTo(scrollView).inset(16)
      make.top.equalTo(scrollView)
      make.bottom.equalTo(scrollView)
    }
  }
}

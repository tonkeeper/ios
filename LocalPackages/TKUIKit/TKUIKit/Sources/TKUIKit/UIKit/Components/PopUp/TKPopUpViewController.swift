import UIKit

public extension TKPopUp {
  final class ViewController: UIViewController, TKBottomSheetScrollContentViewController {
    public var configuration: TKPopUp.Configuration {
      didSet {
        didUpdateConfiguration()
      }
    }
    
    public let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    public var didUpdateHeight: (() -> Void)?
    
    public var headerItem: TKPullCardHeaderItem?
    public var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
    public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
      contentStackView.systemLayoutSizeFitting(
        CGSize(width: width, height: 0),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
      ).height
    }
    
    public init(configuration: TKPopUp.Configuration = .empty) {
      self.configuration = configuration
      super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
      super.viewDidLoad()
      
      setup()
      didUpdateConfiguration()
    }
    
    private func didUpdateConfiguration() {
      contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
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

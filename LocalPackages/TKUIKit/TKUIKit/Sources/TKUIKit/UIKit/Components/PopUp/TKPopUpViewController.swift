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
    private let bottomStackViewContainer = UIView()
    private let bottomStackView = UIStackView()
    
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
    
    public override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      
      bottomStackViewContainer.setNeedsLayout()
      bottomStackViewContainer.layoutIfNeeded()
      
      scrollView.contentInset.bottom = bottomStackViewContainer.frame.height
    }
    
    private func didUpdateConfiguration() {
      contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      for item in configuration.items {
        let view = item.getView()
        contentStackView.addArrangedSubview(view)
        contentStackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(item.bottomSpace)))
      }
      
      bottomStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      for item in configuration.bottomItems {
        let view = item.getView()
        bottomStackView.addArrangedSubview(view)
        bottomStackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(item.bottomSpace)))
      }
    }
    
    private func setup() {
      view.backgroundColor = .Background.page
      
      contentStackView.axis = .vertical
      
      bottomStackView.axis = .vertical
      
      view.addSubview(scrollView)
      view.addSubview(bottomStackViewContainer)
      scrollView.addSubview(contentStackView)
      bottomStackViewContainer.addSubview(bottomStackView)
      
      scrollView.snp.makeConstraints { make in
        make.edges.equalTo(self.view)
      }
      contentStackView.snp.makeConstraints { make in
        make.edges.width.equalTo(scrollView)
      }
      bottomStackViewContainer.snp.makeConstraints { make in
        make.left.bottom.right.equalTo(self.view)
      }
      bottomStackView.snp.makeConstraints { make in
        make.top.left.right.equalTo(bottomStackViewContainer)
        make.bottom.equalTo(bottomStackViewContainer.safeAreaLayoutGuide)
      }
    }
  }
}

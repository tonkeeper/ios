import UIKit

public final class TKModalCardViewController: UIViewController, TKBottomSheetScrollContentViewController {
  public var headerItem: TKPullCardHeaderItem?
  public var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  
  public let scrollView: UIScrollView = {
    TKUIScrollView()
  }()
  
  public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    contentStackView.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    ).height
  }
  
  private let scrollViewContentView = UIView()
  public let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  public var successTitle: String = "Done" {
    didSet {
      actionBarView.successTitle = successTitle
    }
  }
  public var errorTitle: String = "Error" {
    didSet {
      actionBarView.errorTitle = errorTitle
    }
  }
  
  private lazy var headerView = TKModalCardViewController.HeaderView(viewController: self)
  private lazy var contentView = TKModalCardViewController.ContentView(viewController: self)
  private lazy var actionBarView = TKModalCardViewController.ActionBar(viewController: self)
  
  private var actionBarBottomConstraint: NSLayoutConstraint?
  
  private var cachedHeight: CGFloat?
  
  private var _configuration = TKModalCardViewController.Configuration(header: nil)
  public var configuration: TKModalCardViewController.Configuration {
    get { _configuration }
    set { _configuration = newValue; configure() }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateActionBarBottomConstraint()
    if cachedHeight != view.bounds.height {
      cachedHeight = view.bounds.height
      didUpdateHeight?()
    }
  }
  
  public override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateActionBarBottomConstraint()
  }
  
  public var didUpdateHeight: (() -> Void)?
}

private extension TKModalCardViewController {
  func configure() {
    guard isViewLoaded else { return }
    configureHeader()
    configureContent()
    configureActionBar()
    updateActionBarBottomConstraint()
  }
  
  func configureHeader() {
    guard isViewLoaded else { return }
    guard let model = configuration.header else {
      headerView.isHidden = true
      return
    }
    headerView.isHidden = false
    headerView.configure(model: model)
  }
  
  func configureContent() {
    guard isViewLoaded else { return }
    guard let model = configuration.content else {
      contentView.isHidden = true
      return
    }
    contentView.isHidden = false
    contentView.configure(model: model)
  }
  
  func configureActionBar() {
    guard isViewLoaded else { return }
    guard let model = configuration.actionBar else {
      actionBarView.isHidden = true
      return
    }
    actionBarView.isHidden = false
    actionBarView.configure(model: model)
  }
  
  func setup() {
    view.backgroundColor = .Background.page
    
    scrollView.contentInsetAdjustmentBehavior = .never
    
    view.addSubview(scrollView)
    view.addSubview(actionBarView)
    scrollView.addSubview(scrollViewContentView)
    scrollViewContentView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(headerView)
    contentStackView.addArrangedSubview(contentView)
    contentStackView.addArrangedSubview(actionBarView)
    
    setupConstraints()
    
    configure()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollViewContentView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    actionBarView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      scrollViewContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      scrollViewContentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      scrollViewContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      scrollViewContentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      scrollViewContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollViewContentView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollViewContentView.leftAnchor,
                                             constant: 16),
      contentStackView.rightAnchor.constraint(equalTo: scrollViewContentView.rightAnchor,
                                              constant: -16),
      contentStackView.bottomAnchor.constraint(equalTo: scrollViewContentView.bottomAnchor),
    ])
  }
  
  func updateActionBarBottomConstraint() {
    let scrollViewBottomContentInset = actionBarView.isHidden ? 0 : actionBarView.bounds.height
    scrollView.contentInset.bottom = scrollViewBottomContentInset
    actionBarBottomConstraint?.constant = 0
  }
}

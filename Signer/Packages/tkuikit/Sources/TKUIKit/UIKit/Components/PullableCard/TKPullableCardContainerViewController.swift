import UIKit

public final class TKPullableCardContainerViewController: GenericViewViewController<TKPullableCardContainerView> {
  public override var transitioningDelegate: UIViewControllerTransitioningDelegate? {
    get { dimmingTransitioningDelegate }
    set {}
  }
  
  public override var modalPresentationStyle: UIModalPresentationStyle {
    get { .custom }
    set {}
  }
  
  public var content: TKPullableCardContent? {
    didSet {
      guard isViewLoaded else { return }
      cachedHeight = 0
      setupContent()
    }
  }
  
  var scrollableContent: TKPullableCardScrollableContent? {
    content as? TKPullableCardScrollableContent
  }
  
  private let dimmingTransitioningDelegate = DimmingTransitioningDelegate()
  private let panGestureRecognizer = UIPanGestureRecognizer()
  private lazy var scrollController = TKPullableCardContainerScrollController(scrollView: scrollableContent?.scrollView)
  
  // MARK: - State
  
  private var cachedHeight: CGFloat = 0
  
  // MARK: - Init
  
  public init(content: TKPullableCardContent) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }


  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard cachedHeight != view.bounds.height else { return }
    cachedHeight = view.bounds.height
    
    customView.headerView.layoutIfNeeded()
    customView.mainView.layoutIfNeeded()
    
    updateContentHeight()
  }
  
  public func configureHeader(_ model: TKPullableCardHeaderView.Model) {
    customView.headerView.configure(model: model)
  }
}

private extension TKPullableCardContainerViewController {
  func setup() {
    setupContent()
    setupGestures()
    
    customView.headerView.didTapCloseButton = { [weak self] in
      self?.dismiss(animated: true)
    }
  }
  
  func setupContent() {
    guard let content = content else { return }
    
    content.didUpdateHeight = { [weak self] in
      self?.panGestureRecognizer.isEnabled = false
      self?.updateContentHeight()
      self?.panGestureRecognizer.isEnabled = true
    }
    
    content.willMove(toParent: nil)
    customView.removeContentView()
    content.removeFromParent()
    
    addChild(content)
    customView.addContentView(content.view)
    content.didMove(toParent: self)
    
    scrollController.scrollView = scrollableContent?.scrollView
  }
  
  func updateContentHeight() {
    guard let content = content else { return }
    let contentHeight = content.height == 0 ? 1 : content.height
    let maximumContentHeight = customView.maximumContentHeight
    let finalContentHeight = min(contentHeight, maximumContentHeight)
    scrollableContent?.scrollView.isScrollEnabled = contentHeight > maximumContentHeight
    customView.contentHeight = finalContentHeight
    content.view.layoutIfNeeded()
    animateLayout()
  }
  
  func setupGestures() {
    setupPanGesture()
    setupScrollGesture()
  }
  
  func setupPanGesture() {
    panGestureRecognizer.addTarget(
      self,
      action: #selector(panGestureHandler(_:))
    )
    customView.addGestureRecognizer(panGestureRecognizer)
  }
  
  func setupScrollGesture() {
    scrollController.didDrag = { [weak self] offset in
      self?.didDrag(with: max(-.maximumDragOffset, offset * .dragOffsetRatio))
    }
    
    scrollController.didEndDragging = { [weak self] offset, velocity in
      self?.didEndDragging(offset: offset, velocity: velocity)}
  }
  
  func animateLayout() {
    UIView.animate(
      withDuration: .animationDuration,
      delay: .zero,
      usingSpringWithDamping: .animationSpringDamping,
      initialSpringVelocity: .animationSpringVelocity,
      options: [.curveEaseInOut, .allowUserInteraction]) {
        self.customView.layoutIfNeeded()
      }
  }
}

private extension TKPullableCardContainerViewController {
  @objc
  func panGestureHandler(_ recognizer: UIPanGestureRecognizer) {
    let yTranslation = recognizer.translation(in: recognizer.view).y
    let dragOffset = max(-.maximumDragOffset, yTranslation * .dragOffsetRatio)
    switch recognizer.state {
    case .changed:
      didDrag(with: dragOffset)
    case .ended:
      let yVelocity = recognizer.velocity(in: recognizer.view).y
      didEndDragging(offset: dragOffset, velocity: yVelocity)
    case .cancelled, .failed:
      didEndDragging(offset: 0, velocity: 0)
    default:
      break
    }
  }
  
  func didDrag(with offset: CGFloat) {
    customView.dragOffset = offset
  }
  
  func didEndDragging(offset: CGFloat, velocity: CGFloat) {
    let dragDistance = offset / customView.contentHeight
    let isDismiss = dragDistance >= .dragTreshold || velocity >= .velocityTreshold
    if isDismiss {
      dismiss(animated: true)
    } else {
      customView.dragOffset = 0
      animateLayout()
    }
  }
  
  @objc
  func didTapCloseButton() {
    dismiss(animated: true)
  }
}

private extension CGFloat {
  static let maximumDragOffset: CGFloat = 20
  static let dragOffsetRatio: CGFloat = 1/2
  static let dragTreshold: CGFloat = 1/3
  static let velocityTreshold: CGFloat = 1500
  static let animationSpringDamping: CGFloat = 2
  static let animationSpringVelocity: CGFloat = 0
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.4
}

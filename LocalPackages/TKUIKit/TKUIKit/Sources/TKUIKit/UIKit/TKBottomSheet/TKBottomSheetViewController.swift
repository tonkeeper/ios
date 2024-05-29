import UIKit

public final class TKBottomSheetViewController: UIViewController {
  
  public var didClose: ((_ interactivly: Bool) -> Void)?
  
  let dimmingView = TKBottomSheetDimmingView()
  let containerView = UIView()
  let headerView = TKBottomSheetHeaderView()
  let contentViewController: TKBottomSheetContentViewController
  
  private let scrollController = TKBottomSheetScrollController()
  
  private lazy var tapGesture = UITapGestureRecognizer(
    target: self,
    action: #selector(tapGestureHandler)
  )
  
  private lazy var panGesture = UIPanGestureRecognizer(
    target: self,
    action: #selector(panGestureHandler(_:))
  )
  
  private var headerHeight: CGFloat {
    headerView.systemLayoutSizeFitting(CGSize(width: view.bounds.width, height: 0)).height
  }
  
  private var contentMaximumHeight: CGFloat {
    view.frame.height
    - view.safeAreaInsets.top
    - bottomSpacing
    - headerHeight
  }
  
  private var bottomSpacing: CGFloat {
    view.safeAreaInsets.bottom
  }

  private var containerFrame: CGRect = .zero
  
  public init(contentViewController: TKBottomSheetContentViewController) {
    self.contentViewController = contentViewController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    dimmingView.frame = view.bounds
  }
  
  public func present(fromViewController: UIViewController) {
    let navigationController = TKNavigationController(rootViewController: self)
    navigationController.configureTransparentAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.modalPresentationStyle = .overFullScreen
    
    fromViewController.present(navigationController, animated: false) {
      self.setup()
      self.performPresent()
    }
  }
  
  public func dismiss(completion: (() -> Void)? = nil) {
    performDismiss(completion: { [weak self] in
      self?.navigationController?.dismiss(animated: false, completion: completion)
    })
  }
}

private extension TKBottomSheetViewController {
  func setup() {
    view.backgroundColor = .clear
    
    dimmingView.prepareForPresentationTransition()
    
    containerView.backgroundColor = .Background.page
    containerView.layer.cornerRadius = 16
    containerView.layer.masksToBounds = true
    
    view.addSubview(dimmingView)
    view.addSubview(containerView)
    
    dimmingView.addGestureRecognizer(tapGesture)
    containerView.addGestureRecognizer(panGesture)
  }
  
  func setupContent() {
    addChild(contentViewController)
    containerView.addSubview(contentViewController.view)
    contentViewController.didMove(toParent: self)
    
    contentViewController.didUpdateHeight = { [weak self] in
      self?.updateContentHeight()
    }
  }
  
  func setupHeader() {
    containerView.addSubview(headerView)
    headerView.configure(model: contentViewController.headerItem)
    contentViewController.didUpdatePullCardHeaderItem = { [headerView] in
      headerView.configure(model: $0)
    }
    
    headerView.closeButton.addTapAction { [weak self] in
      self?.dismiss(completion: { [weak self] in
        self?.didClose?(true)
      })
    }
  }
  
  func updateContentHeight() {
    let contentHeight = calculateContentHeight()
    let containerHeigth = contentHeight + headerHeight + bottomSpacing
    containerFrame.size.height = containerHeigth
    containerFrame.origin.y = view.bounds.height - containerHeigth
    
    contentViewController.view.frame.origin.y = headerHeight
    contentViewController.view.frame.size.height = contentHeight
    contentViewController.view.setNeedsLayout()
    contentViewController.view.layoutIfNeeded()
    
    animateDragging {
      self.containerView.frame = self.containerFrame
    }
  }

  func performPresent() {
    view.setNeedsLayout()
    view.layoutIfNeeded()
    setupHeader()
    setupContent()
    containerView.frame.size.width = view.bounds.width
    let contentHeight = calculateContentHeight()
    
    let containerHeigth = contentHeight + headerHeight + bottomSpacing
    containerFrame = CGRect(x: 0, y: view.bounds.height - containerHeigth, width: view.bounds.width, height: containerHeigth)
    
    let headerFrame = CGRect(x: 0, y: 0, width: containerFrame.width, height: headerHeight)
    
    let contentFrame = CGRect(x: 0, y: headerFrame.maxY, width: containerFrame.width, height: contentHeight)
    
    containerView.frame = containerFrame
    headerView.frame = headerFrame
    contentViewController.view.frame = contentFrame
    
    containerView.frame.origin.y = view.bounds.height
    
    view.setNeedsLayout()
    view.layoutIfNeeded()
    
    dimmingView.prepareForPresentationTransition()
    
    animateDragging {
      self.dimmingView.performPresentationTransition()
      self.containerView.frame.origin.y = self.view.bounds.height - self.containerView.frame.size.height
    }
  }
  
  func performDismiss(completion: (() -> Void)? = nil) {
    dimmingView.prepareForDimissalTransition()
    animateDragging {
      self.containerView.frame.origin.y = self.view.bounds.height
      self.dimmingView.performDismissalTransition()
    } completion: { _ in
      completion?()
    }
  }
  
  private func calculateContentHeight() -> CGFloat {
    if let scrollableContent = contentViewController as? TKBottomSheetScrollContentViewController {
      scrollableContent.view.frame = view.bounds
      scrollableContent.scrollView.frame = view.bounds
      scrollableContent.scrollView.setNeedsLayout()
      scrollableContent.scrollView.layoutIfNeeded()

      scrollController.scrollView = scrollableContent.scrollView

      scrollController.didEndDragging = { [weak self] offset, _ in
        self?.didEndDragging(offset: offset)
      }

      scrollController.didDrag = { [weak self] offset in
        self?.didDrag(offset: offset)
      }
      
      let contentHeight = scrollableContent.calculateHeight(withWidth: containerView.bounds.width)
      let adjustedHeight = min(contentMaximumHeight, contentHeight)
      scrollableContent.scrollView.isScrollEnabled = adjustedHeight < contentHeight

      return adjustedHeight
    } else {
      let contentHeight = contentViewController.calculateHeight(withWidth: containerView.bounds.width)
      let adjustedHeight = min(contentMaximumHeight, contentHeight)
      return adjustedHeight
    }
  }
  
  @objc private func tapGestureHandler() {
    dismiss(completion: { [weak self] in
      self?.didClose?(true)
    })
  }
  
  @objc private func panGestureHandler(_ recognizer: UIPanGestureRecognizer) {
    switch recognizer.state {
    case .changed:
      let translation = recognizer.translation(in: recognizer.view)
      didDrag(offset: translation.y)
    case .ended:
      let translation = recognizer.translation(in: recognizer.view)
      didEndDragging(offset: translation.y)
    case .cancelled, .failed:
      didFailedDrag()
    default:
      break
    }
  }
  
  func didDrag(offset: CGFloat) {
    if offset < 0 {
      let delta = max(offset, -.maximumDragOffset)
      containerView.frame.origin.y = containerFrame.origin.y + delta
      containerView.frame.size.height = containerFrame.size.height - delta
    } else {
      containerView.frame.origin.y = containerFrame.origin.y + offset
    }
  }
  
  func didEndDragging(offset: CGFloat) {
    if offset > 60 {
      dismiss { [weak self] in
        self?.didClose?(true)
      }
    } else {
      animateDragging {
        self.containerView.frame = self.containerFrame
      }
    }
  }
  
  func didFailedDrag() {
    animateDragging {
      self.containerView.frame = self.containerFrame
    }
  }
  
  func animateDragging(animations: @escaping () -> Void,
                       completion: ((Bool) -> Void)? = nil) {
    UIView.animate(
      withDuration: .animationDuration,
      delay: .zero,
      usingSpringWithDamping: .animationSpringDamping,
      initialSpringVelocity: .animationSpringVelocity,
      options: [.curveEaseInOut, .allowUserInteraction],
      animations: animations,
      completion: completion)
  }
}

private extension CGFloat {
  static let maximumDragOffset: CGFloat = 24
  static let dragOffsetRatio: CGFloat = 1/2
  static let dragTreshold: CGFloat = 1/3
  static let velocityTreshold: CGFloat = 1500
  static let animationSpringDamping: CGFloat = 2
  static let animationSpringVelocity: CGFloat = 0
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.4
}

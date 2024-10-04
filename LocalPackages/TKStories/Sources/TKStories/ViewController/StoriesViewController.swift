import UIKit
import TKUIKit

public final class StoriesViewController: UIViewController {
  
  private let bar = ProgressBarView()
  private let closeButton: TKButton = {
    var configuration = TKButton.Configuration.headerAccentButtonConfiguration()
    configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.close)
    configuration.iconTintColor = .black
    configuration.backgroundColors = [
      .normal: .Button.overlayBackground,
      .highlighted: .Button.overlayBackgroundHighlighted]
    configuration.contentPadding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    configuration.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    configuration.cornerRadius = 16
    let button = TKButton(configuration: configuration)
    return button
  }()
  private let pageContainerView = UIView()
  
  private var activePage: Int {
    get {
      _activePage
    }
    set {
      _activePage = newValue
      didChangeActivePage()
    }
  }
  private var _activePage = 0
  private var didStart = false
  private var timer: ResumableTimer?
  
  private let models: [StoriesPageModel]
  private let pageDuration: TimeInterval
  
  init(models: [StoriesPageModel],
       pageDuration: TimeInterval = 5) {
    self.models = models
    self.pageDuration = pageDuration
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    start()
  }
  
  private func setup() {
    bar.barsCount = models.count
    _activePage = 0
    
    closeButton.configuration.action = { [weak self] in
      self?.dismiss(animated: true)
    }
    
    view.backgroundColor = .red
    view.addSubview(pageContainerView)
    view.addSubview(bar)
    view.addSubview(closeButton)
    
    pageContainerView.snp.makeConstraints { make in
      make.edges.equalTo(view)
    }
    
    bar.snp.makeConstraints { make in
      make.top.equalTo(view)
      make.left.right.equalTo(view)
    }
    closeButton.snp.makeConstraints { make in
      make.top.equalTo(bar.snp.bottom).offset(-8)
      make.right.equalTo(view).inset(8)
    }
    
    setupGestures()
  }
  
  private func setupGestures() {
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapGestureRecognizer.delegate = self
    self.view.addGestureRecognizer(tapGestureRecognizer)
    
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    longPressGesture.minimumPressDuration = 0.2
    self.view.addGestureRecognizer(longPressGesture)
  }
  
  private func start() {
    guard !didStart else { return }
    activePage = 0
    didStart = true
  }
  
  private func didChangeActivePage() {
    bar.setActivePage(index: _activePage, animationDuration: pageDuration)
    timer = ResumableTimer(interval: pageDuration, callback: { [weak self] in
      self?.activateNextPage()
    })
    timer?.start()
    pageContainerView.removeSubviews()
    let pageViewController = StoriesPageViewController(model: models[_activePage])
    
    addChild(pageViewController)
    pageContainerView.addSubview(pageViewController.view)
    pageViewController.didMove(toParent: self)
    
    pageViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(pageContainerView)
    }
  }
  
  private func activateNextPage() {
    let nextIndex = min(_activePage + 1, models.count - 1)
    guard nextIndex != _activePage else { return  }
    guard nextIndex < models.count else {
      return
    }
    activePage = nextIndex
  }
  
  private func activatePreviousPage() {
    let nextIndex = max (_activePage - 1, 0)
    guard nextIndex >= 0 else {
      return
    }
    activePage = nextIndex
  }
  
  @objc
  private func handleTap(_ gesture: UITapGestureRecognizer) {
    let tapLocation = gesture.location(in: self.view)
    let screenWidth = self.view.bounds.width
    
    if tapLocation.x < screenWidth / 2 {
      activatePreviousPage()
    } else {
      activateNextPage()
    }
  }
  
  @objc
  private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    switch gesture.state {
    case .began:
      bar.pause()
      timer?.pause()
      updateBarVisibility(false, delay: 0.2, animationDuration: 0.2)
    case .cancelled, .ended, .failed:
      bar.resume()
      timer?.resume()
      updateBarVisibility(true, delay: 0, animationDuration: 0.2)
    default: break
    }
  }
  
  private func updateBarVisibility(_ isVisible: Bool, delay: CGFloat, animationDuration: TimeInterval) {
    UIView.animate(withDuration: animationDuration, delay: delay, options: .curveEaseOut) {
      self.bar.alpha = isVisible ? 1 : 0
      self.closeButton.alpha = isVisible ? 1 : 0
    }
  }
}

extension StoriesViewController: UIGestureRecognizerDelegate {
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    guard touch.view is UIControl else {
      return true
    }
    return false
  }
}

final class ResumableTimer {
  
  private var timer: Timer?
  private var callback: () -> Void
  
  private var startTime: TimeInterval?
  private var elapsedTime: TimeInterval?
  
  // MARK: Init
  
  init(interval: Double, callback: @escaping () -> Void) {
    self.callback = callback
    self.interval = interval
  }
  
  private var interval: Double = 0.0
  
  func isPaused() -> Bool {
    guard let timer = timer else { return false }
    return !timer.isValid
  }
  
  func start() {
    runTimer(interval: interval)
  }
  
  func pause() {
    elapsedTime = Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
    timer?.invalidate()
  }
  
  func resume() {
    interval -= elapsedTime ?? 0.0
    runTimer(interval: interval)
  }
  
  func invalidate() {
    timer?.invalidate()
  }
  
  func reset() {
    startTime = Date.timeIntervalSinceReferenceDate
    runTimer(interval: interval)
  }
  
  private func runTimer(interval: Double) {
    startTime = Date.timeIntervalSinceReferenceDate
    let timer = Timer(timeInterval: interval, repeats: false) { [weak self] timer in
      self?.callback()
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }
}

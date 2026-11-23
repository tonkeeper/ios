import TKUIKit
import UIKit

public final class StoriesViewController: UIViewController {
    public var didOpen: (() -> Void)?
    public var didOpenPage: ((_ pageNumber: Int) -> Void)?
    public var didComplete: (() -> Void)?
    public var didTapClose: (() -> Void)?

    public var storiesPresentationController: StoriesPresentationController? {
        presentationController as? StoriesPresentationController
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    private let bar = ProgressBarView()
    private let closeButton: TKButton = {
        var configuration = TKButton.Configuration.headerAccentButtonConfiguration()
        configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.close)
        configuration.iconTintColor = .black
        configuration.backgroundColors = [
            .normal: .Button.overlayBackground,
            .highlighted: .Button.overlayBackgroundHighlighted,
        ]
        configuration.contentPadding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        configuration.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        configuration.cornerRadius = 16
        let button = TKButton(configuration: configuration)
        button.accessibilityIdentifier = "stories_close"
        return button
    }()

    private let pageContainerView = UIView()
    private weak var activePageViewController: StoriesPageViewController?

    public var activePageIndex: Int {
        _activePage
    }

    private var activePage: Int {
        get {
            _activePage
        }
        set {
            _activePage = newValue
            openActivePage()
            updatePlayback()
        }
    }

    private enum PauseReason {
        case hidden
        case background
        case hold
        case closing
    }

    private var _activePage = 0
    private var initialPage: Int?
    private var timer: ResumableTimer?
    private var pauseReasons: Set<PauseReason> = [.hidden]
    private var isPlaying = false

    private lazy var longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    private let trasitionManager = StoriesModalTransitionManager()

    private var isFirstAppear = true

    private let models: [StoriesPageModel]
    private let pageDuration: TimeInterval

    init(
        models: [StoriesPageModel],
        pageDuration: TimeInterval = 5
    ) {
        self.models = models
        self.pageDuration = pageDuration
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = trasitionManager
        self.modalPresentationCapturesStatusBarAppearance = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
        openActivePage()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isFirstAppear {
            didOpen?()
            isFirstAppear = false
        }
        resumePlayback(.hidden)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pausePlayback(.hidden)
    }

    @objc
    func didEnterBackground() {
        pausePlayback(.background)
    }

    @objc
    func didBecomeActive() {
        resumePlayback(.background)
    }

    private func setup() {
        bar.barsCount = models.count
        bar.animationDuration = pageDuration
        _activePage = min(initialPage ?? 0, models.count - 1)

        closeButton.configuration.action = { [weak self] in
            self?.close()
        }

        view.backgroundColor = .Background.page
        view.addSubview(pageContainerView)
        view.addSubview(bar)
        view.addSubview(closeButton)

        pageContainerView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }

        bar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalTo(view)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(bar.snp.bottom).offset(-8)
            make.right.equalTo(view).inset(8)
        }

        setupGestures()
    }

    public func setInitialPage(_ index: Int) {
        initialPage = index
    }

    func close() {
        guard let didTapClose else {
            dismiss(animated: true)
            return
        }
        pausePlayback(.closing)
        didTapClose()
    }

    private func setupGestures() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(tapGestureRecognizer)

        longPressGesture.minimumPressDuration = 0.2
        longPressGesture.delegate = self
        self.view.addGestureRecognizer(longPressGesture)
    }

    private func pausePlayback(_ reason: PauseReason) {
        pauseReasons.insert(reason)
        updatePlayback()
    }

    private func resumePlayback(_ reason: PauseReason) {
        pauseReasons.remove(reason)
        updatePlayback()
    }

    /// The page timer and its progress bar start only once the page shows its content, and hold
    /// while any pause reason is active. A page counts as opened when its timer first starts, so
    /// a page closed while still loading is not marked watched.
    private func updatePlayback() {
        let shouldPlay = pauseReasons.isEmpty && activePageViewController?.isReady == true
        guard shouldPlay != isPlaying else { return }
        isPlaying = shouldPlay
        guard shouldPlay else {
            bar.pause()
            timer?.pause()
            return
        }
        if let timer {
            bar.resume()
            timer.resume()
        } else {
            bar.setActivePage(index: _activePage, isRunning: true)
            let timer = ResumableTimer(interval: pageDuration, callback: { [weak self] in
                self?.activateNextPage()
            })
            timer.start()
            self.timer = timer
            didOpenPage?(_activePage)
        }
    }

    private func openActivePage() {
        timer = nil
        isPlaying = false
        bar.setActivePage(index: _activePage, isRunning: false)

        if let activePageViewController {
            activePageViewController.willMove(toParent: nil)
            activePageViewController.view.removeFromSuperview()
            activePageViewController.removeFromParent()
        }
        guard !models.isEmpty, models.count > _activePage else { return }
        let pageViewController = StoriesPageViewController(model: models[_activePage])
        pageViewController.didBecomeReady = { [weak self, weak pageViewController] in
            guard let self, pageViewController === activePageViewController else { return }
            updatePlayback()
        }
        activePageViewController = pageViewController

        addChild(pageViewController)
        pageContainerView.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalTo(pageContainerView)
        }
    }

    private func activateNextPage() {
        let nextIndex = _activePage + 1
        guard nextIndex < models.count else {
            didComplete?()
            return
        }
        activePage = nextIndex
    }

    private func activatePreviousPage() {
        let nextIndex = max(_activePage - 1, 0)
        guard nextIndex >= 0 else {
            return
        }
        activePage = nextIndex
    }

    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        if let link = activePageViewController?.link(at: gesture) {
            link.action()
            return
        }

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
            pausePlayback(.hold)
            updateBarVisibility(false, delay: 0.2, animationDuration: 0.2)
        case .cancelled, .ended, .failed:
            resumePlayback(.hold)
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
        guard !isPaused() else { return }
        elapsedTime = Date.timeIntervalSinceReferenceDate - (startTime ?? 0.0)
        timer?.invalidate()
    }

    func resume() {
        guard isPaused() else { return }
        interval -= elapsedTime ?? 0.0
        runTimer(interval: interval)
    }

    private func runTimer(interval: Double) {
        startTime = Date.timeIntervalSinceReferenceDate
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.callback()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

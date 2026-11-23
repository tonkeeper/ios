import TKLogging
import UIKit

open class TKWindow: UIWindow {
    private var token: NSObjectProtocol?
    private var touchIndicatorViews = [ObjectIdentifier: TouchIndicatorView]()
    private var showsTouches = false {
        didSet {
            updateTouchOverlayVisibility()
        }
    }

    private lazy var touchOverlayView: UIView = {
        let view = UIView(frame: bounds)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override public init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        guard showsTouches, let allTouches = event.allTouches else {
            return
        }

        bringSubviewToFront(touchOverlayView)

        for touch in allTouches {
            handleTouch(touch)
        }
    }

    override open func buildMenu(with builder: UIMenuBuilder) {
        if #available(iOS 17.0, *), builder.system == .context,
           (firstResponderDescendant as? UITextField)?.keyboardType == .decimalPad
        {
            builder.remove(menu: .autoFill)
        }
        super.buildMenu(with: builder)
    }

    deinit {
        token = nil
        Log.d("TKWindow with window level \(self.windowLevel.rawValue) deinit")
    }
}

private extension TKWindow {
    func setup() {
        TKThemeManager.shared.addEventObserver(self) { observer, theme in
            observer.updateUserInterfaceStyle(theme.themeAppaearance.userInterfaceStyle)
        }
        TKDevPreferencesManager.shared.addEventObserver(self) { observer, preferences in
            observer.setShowsTouches(preferences.showsTouches)
        }
        updateUserInterfaceStyle(TKThemeManager.shared.theme.themeAppaearance.userInterfaceStyle)
        setShowsTouches(TKDevPreferencesManager.shared.showsTouches)
        updateTouchOverlayVisibility()
    }

    func setShowsTouches(_ showsTouches: Bool) {
        self.showsTouches = showsTouches
    }

    private func updateUserInterfaceStyle(_ userInterfaceStyle: UIUserInterfaceStyle) {
        if traitCollection.userInterfaceStyle == userInterfaceStyle {
            if traitCollection.userInterfaceStyle == .light {
                overrideUserInterfaceStyle = .dark
            } else {
                overrideUserInterfaceStyle = .light
            }
        }
        overrideUserInterfaceStyle = userInterfaceStyle
    }

    private func updateTouchOverlayVisibility() {
        if showsTouches {
            if touchOverlayView.superview == nil {
                addSubview(touchOverlayView)
            }
            bringSubviewToFront(touchOverlayView)
        } else {
            touchIndicatorViews.values.forEach { $0.removeFromSuperview() }
            touchIndicatorViews.removeAll()
            touchOverlayView.removeFromSuperview()
        }
    }

    private func handleTouch(_ touch: UITouch) {
        let identifier = ObjectIdentifier(touch)
        let location = touch.location(in: self)

        switch touch.phase {
        case .began:
            let indicatorView = TouchIndicatorView()
            touchOverlayView.addSubview(indicatorView)
            touchIndicatorViews[identifier] = indicatorView
            indicatorView.show(at: location)
        case .moved, .stationary:
            touchIndicatorViews[identifier]?.move(to: location)
        case .ended, .cancelled:
            guard let indicatorView = touchIndicatorViews.removeValue(forKey: identifier) else {
                return
            }
            indicatorView.hide(at: location)
        case .regionEntered, .regionMoved, .regionExited:
            break
        @unknown default:
            break
        }
    }
}

private final class TouchIndicatorView: UIView {
    private static let size = CGSize(width: 44, height: 44)

    init() {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.22)
        layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        layer.borderWidth = 2
        layer.cornerRadius = Self.size.width / 2
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(at location: CGPoint) {
        center = location
        layer.removeAllAnimations()
        UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func move(to location: CGPoint) {
        center = location
    }

    func hide(at location: CGPoint) {
        center = location
        layer.removeAllAnimations()
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
            },
            completion: { _ in
                self.removeFromSuperview()
            }
        )
    }
}

private extension UIView {
    var firstResponderDescendant: UIView? {
        isFirstResponder ? self : subviews.lazy.compactMap(\.firstResponderDescendant).first
    }
}

public extension UIApplication {
    static var keyWindow: UIWindow? {
        self
            .shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows }
            .flatMap { $0 }
            .last { $0.isKeyWindow }
    }

    static var keyWindowScene: UIWindowScene? {
        self
            .keyWindow?
            .windowScene
    }
}

public extension UIViewController {
    var windowScene: UIWindowScene? {
        view.window?.windowScene ?? UIApplication.keyWindowScene
    }
}

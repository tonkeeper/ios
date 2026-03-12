import TKLogging
import UIKit

open class TKWindow: UIWindow {
    private var token: NSObjectProtocol?

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
        updateUserInterfaceStyle(TKThemeManager.shared.theme.themeAppaearance.userInterfaceStyle)
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

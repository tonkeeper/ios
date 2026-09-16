import Foundation
import TKLocalize
import TKUIKit

public extension ToastPresenter.Configuration {
    static func defaultConfiguration(text: String) -> ToastPresenter.Configuration {
        ToastPresenter.Configuration(title: text)
    }

    static func confirmed(text: String) -> ToastPresenter.Configuration {
        ToastPresenter.Configuration(
            title: text,
            icon: .TKUIKit.Icons.Size16.checkmarkCircle,
            iconTintColor: .Accent.green
        )
    }

    static func warning(text: String) -> ToastPresenter.Configuration {
        ToastPresenter.Configuration(
            title: text,
            icon: .TKUIKit.Icons.Size16.exclamationmarkTriangle,
            iconTintColor: .Accent.orange
        )
    }

    static var noInternetConnection: ToastPresenter.Configuration {
        .warning(text: TKLocales.ConnectionStatus.noInternet)
            .withPlacement(.navigationBar)
    }

    static var copied: ToastPresenter.Configuration {
        .confirmed(text: TKLocales.Toast.copied)
    }

    static var loading: ToastPresenter.Configuration {
        ToastPresenter.Configuration(
            title: TKLocales.Toast.loading,
            isActivity: true,
            dismissRule: .none
        )
    }

    static var failed: ToastPresenter.Configuration {
        .defaultConfiguration(text: TKLocales.Toast.failed)
    }

    func withPlacement(_ placement: Placement) -> ToastPresenter.Configuration {
        var configuration = self
        configuration.placement = placement
        return configuration
    }

    func withSwipeToDismiss(_ allowsSwipeToDismiss: Bool) -> ToastPresenter.Configuration {
        var configuration = self
        configuration.allowsSwipeToDismiss = allowsSwipeToDismiss
        return configuration
    }
}

extension ToastPresenter {
    static func showNoInternetConnectionToastIfNeeded(
        isOffline: @escaping () -> Bool,
        after delay: TimeInterval = 0.35
    ) {
        guard isOffline() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isOffline() else { return }
            showToast(configuration: .noInternetConnection)
        }
    }
}

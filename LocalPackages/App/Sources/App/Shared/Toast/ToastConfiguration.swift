import TKUIKit
import TKLocalize

public extension ToastPresenter.Configuration {
  
  static func defaultConfiguration(text: String) -> ToastPresenter.Configuration {
    ToastPresenter.Configuration(
      title: text,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary,
      dismissRule: .default
    )
  }

  static var copied: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Toast.copied,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
  
  static var loading: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Toast.loading,
      shape: .oval,
      isActivity: true,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary,
      dismissRule: .none
    )
  }
  
  static var failed: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Toast.failed,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
}

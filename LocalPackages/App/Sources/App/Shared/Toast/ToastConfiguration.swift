import TKUIKit
import TKLocalize

public extension ToastPresenter.Configuration {

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

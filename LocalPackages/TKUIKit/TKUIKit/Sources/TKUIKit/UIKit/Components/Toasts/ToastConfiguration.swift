import TKLocalize

public extension ToastPresenter.Configuration {

  static var copied: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Actions.copied,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
  
  static var loading: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Actions.loading,
      shape: .oval,
      isActivity: true,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary,
      dismissRule: .none
    )
  }
  
  static var failed: ToastPresenter.Configuration {
    .init(
      title: TKLocales.Actions.failed,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
}

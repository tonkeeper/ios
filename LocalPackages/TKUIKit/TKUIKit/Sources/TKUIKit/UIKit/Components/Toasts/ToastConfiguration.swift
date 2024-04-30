public extension ToastPresenter.Configuration {
  static var copied: ToastPresenter.Configuration {
    .init(
      title: "Copied",
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
  
  static var loading: ToastPresenter.Configuration {
    .init(
      title: "Loading",
      shape: .oval,
      isActivity: true,
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary,
      dismissRule: .none
    )
  }
  
  static var failed: ToastPresenter.Configuration {
    .init(
      title: "Failed",
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
}

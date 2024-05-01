public extension ToastPresenter.Configuration {
  static var copied: ToastPresenter.Configuration {
    .init(title: "Copied")
  }
  
  static var loading: ToastPresenter.Configuration {
    .init(title: "Loading", shape: .oval, isActivity: true, dismissRule: .none)
  }
  
  static var failed: ToastPresenter.Configuration {
    .init(title: "Failed")
  }
}

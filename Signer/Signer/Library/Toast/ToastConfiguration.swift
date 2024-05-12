import TKUIKit
import SignerLocalize

extension ToastPresenter.Configuration {
  enum Signer {
    static var copied: ToastPresenter.Configuration {
      .init(
        title: SignerLocalize.Toast.copied,
        backgroundColor: .Background.contentTint,
        foregroundColor: .Text.primary
      )
    }
    static var passwordChanged: ToastPresenter.Configuration {
      .init(
        title: SignerLocalize.Toast.password_changed,
        backgroundColor: .Background.contentTint,
        foregroundColor: .Text.primary
      )
    }
    static var passwordChangeFailed: ToastPresenter.Configuration {
      .init(
        title: SignerLocalize.Toast.failed,
        backgroundColor: .Background.contentTint,
        foregroundColor: .Text.primary
      )
    }
  }
}


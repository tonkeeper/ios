public enum SignerLocalize {
  public enum Actions {
    /// Continue
    public static var continue_action: String {
      localize("actions.continue_action")
    }
    /// Cancel
    public static var cancel: String {
      localize("actions.cancel")
    }
    /// Copy
    public static var copy: String {
      localize("actions.copy")
    }
    /// Save
    public static var save: String {
      localize("actions.save")
    }
    /// Paste
    public static var paste: String {
      localize("actions.paste")
    }
  }
  public enum Toast {
    /// Copied
    public static var copied: String {
      localize("toast.copied")
    }
    /// Password changed
    public static var password_changed: String {
      localize("toast.password_changed")
    }
    /// Failed
    public static var failed: String {
      localize("toast.failed")
    }
  }
  public enum App {
    /// Signer
    public static var name: String {
      localize("app.name")
    }
  }
  public enum Onboarding {
    /// The storage place for your keys to sign transactions in Tonkeeper
    public static var caption: String {
      localize("onboarding.caption")
    }
  }
  public enum Password {
    public enum Create {
      /// Create Password
      public static var title: String {
        localize("password.create.title")
      }
      public enum Textfield {
        /// Minimum 4 characters
        public static var caption: String {
          localize("password.create.textfield.caption")
        }
      }
    }
    public enum Reenter {
      /// Re-enter Password
      public static var title: String {
        localize("password.reenter.title")
      }
    }
    public enum Enter {
      /// Enter Password
      public static var title: String {
        localize("password.enter.title")
      }
    }
    public enum Change {
      public enum EnterCurrent {
        /// Enter current Password
        public static var title: String {
          localize("password.change.enter_current.title")
        }
      }
      public enum EnterNew {
        /// Enter new Password
        public static var title: String {
          localize("password.change.enter_new.title")
        }
      }
      public enum ReenterNew {
        /// Re-enter Password
        public static var title: String {
          localize("password.change.reenter_new.title")
        }
      }
    }
    public enum Confirmation {
      /// Enter current Password
      public static var title: String {
        localize("password.confirmation.title")
      }
    }
  }
  public enum NameKey {
    /// Name your Key
    public static var title: String {
      localize("name_key.title")
    }
    /// It will simplify the search for the necessary key in the list of keys.
    public static var caption: String {
      localize("name_key.caption")
    }
    public enum Textfield {
      /// Name
      public static var placeholder: String {
        localize("name_key.textfield.placeholder")
      }
    }
  }
  public enum Main {
    public enum Buttons {
      public enum Scan {
        /// Scan
        public static var title: String {
          localize("main.buttons.scan.title")
        }
      }
      public enum AddKey {
        /// Add Key
        public static var title: String {
          localize("main.buttons.addKey.title")
        }
      }
      public enum Settings {
        /// Settings
        public static var title: String {
          localize("main.buttons.settings.title")
        }
      }
    }
  }
  public enum KeyDetails {
    public enum QrHeader {
      /// Export to another device
      public static var title: String {
        localize("key_details.qr_header.title")
      }
      /// Open Tonkeeper » Add Wallet » Pair Tonsign
      public static var caption: String {
        localize("key_details.qr_header.caption")
      }
    }
    public enum Buttons {
      /// Export to Tonkeeper
      public static var export_to_tonkeeper: String {
        localize("key_details.buttons.export_to_tonkeeper")
      }
      /// Export to Tonkeeper Web
      public static var export_to_tonkeeper_web: String {
        localize("key_details.buttons.export_to_tonkeeper_web")
      }
      /// Name
      public static var name: String {
        localize("key_details.buttons.name")
      }
      /// Hex Address
      public static var hex_address: String {
        localize("key_details.buttons.hex_address")
      }
      /// Recovery Phrase
      public static var recovery_phrase: String {
        localize("key_details.buttons.recovery_phrase")
      }
      /// Delete Key
      public static var delete_key: String {
        localize("key_details.buttons.delete_key")
      }
    }
    public enum DeleteAlert {
      /// Delete Key?
      public static var title: String {
        localize("key_details.delete_alert.title")
      }
      /// This will erase key to the wallet. Make sure you have backed up your secret recovery phrase.
      public static var description: String {
        localize("key_details.delete_alert.description")
      }
      public enum Buttons {
        /// Delete Key
        public static var delete_key: String {
          localize("key_details.delete_alert.buttons.delete_key")
        }
      }
    }
  }
  public enum AddKey {
    /// Add Key
    public static var title: String {
      localize("add_key.title")
    }
    /// Create a new key or add an existing one.
    public static var caption: String {
      localize("add_key.caption")
    }
    public enum Buttons {
      /// Create New Key
      public static var create_new: String {
        localize("add_key.buttons.create_new")
      }
      /// Import Existing Key
      public static var import_existing: String {
        localize("add_key.buttons.import_existing")
      }
    }
  }
  public enum Settings {
    /// Settings
    public static var title: String {
      localize("settings.title")
    }
    public enum Items {
      /// Change Password
      public static var change_password: String {
        localize("settings.items.change_password")
      }
      /// Support
      public static var support: String {
        localize("settings.items.support")
      }
      /// Legal
      public static var legal: String {
        localize("settings.items.legal")
      }
      /// Theme
      public static var theme: String {
        localize("settings.items.theme")
      }
    }
    public enum Footer {
      /// Version %@
      public static func version(_ p0: Any) -> String {
        return localizeWithArgs("settings.footer.version", String(describing: p0))
      }
    }
    public enum Themes {
      /// Deep Blue
      public static var deepblue: String {
        localize("settings.themes.deepblue")
      }
      /// Dark
      public static var dark: String {
        localize("settings.themes.dark")
      }
      /// Light
      public static var light: String {
        localize("settings.themes.light")
      }
      /// System
      public static var system: String {
        localize("settings.themes.system")
      }
    }
    public enum Legal {
      /// Legal
      public static var title: String {
        localize("settings.legal.title")
      }
      public enum Items {
        /// Terms of service
        public static var terms_of_service: String {
          localize("settings.legal.items.terms_of_service")
        }
        /// Privacy policy
        public static var privacy_policy: String {
          localize("settings.legal.items.privacy_policy")
        }
        /// Montserrat font
        public static var montserrat_font: String {
          localize("settings.legal.items.montserrat_font")
        }
      }
      public enum Sections {
        /// Licences
        public static var licenses: String {
          localize("settings.legal.sections.licenses")
        }
      }
    }
  }
  public enum Recovery {
    public enum Phrase {
      /// Recovery Phrase
      public static var title: String {
        localize("recovery.phrase.title")
      }
      /// Write these words with their numbers and store them in a safe place down. Do not enter it into unknown apps.
      public static var caption: String {
        localize("recovery.phrase.caption")
      }
    }
  }
  public enum RecoveryInput {
    /// Enter Recovery Phrase
    public static var title: String {
      localize("recovery_input.title")
    }
    /// When you created this wallet, you got a 24-word recovery phrase. Enter it to restore access to your wallet.
    public static var caption: String {
      localize("recovery_input.caption")
    }
    public enum Banner {
      /// It's safer to create a new key in Signer. Your old key may have been compromised by you previously.
      public static var text: String {
        localize("recovery_input.banner.text")
      }
    }
  }
  public enum Scanner {
    /// Scan QR code
    public static var title: String {
      localize("scanner.title")
    }
    /// From Tonkeeper on the action confirmation page
    public static var caption: String {
      localize("scanner.caption")
    }
  }
  public enum CameraPermission {
    /// Enable access to your camera in order to can scan QR codes
    public static var title: String {
      localize("camera_permission.title")
    }
    /// Open Settings
    public static var button: String {
      localize("camera_permission.button")
    }
  }
  public enum SignTransaction {
    /// Sign Transaction
    public static var title: String {
      localize("sign_transaction.title")
    }
    /// Audit Transaction
    public static var audit_transaction: String {
      localize("sign_transaction.audit_transaction")
    }
    /// Emulate in Browser
    public static var emulate: String {
      localize("sign_transaction.emulate")
    }
    /// Copy
    public static var copy: String {
      localize("sign_transaction.copy")
    }
    /// Slide to Sign
    public static var slide_to_sign: String {
      localize("sign_transaction.slide_to_sign")
    }
    /// Send
    public static var send: String {
      localize("sign_transaction.send")
    }
  }
  public enum SignTransactionQr {
    /// Scan the QR code with Tonkeeper
    public static var title: String {
      localize("sign_transaction_qr.title")
    }
    /// After scanning, the transaction will be sent to the network.
    public static var caption: String {
      localize("sign_transaction_qr.caption")
    }
    /// Signed Transaction
    public static var signed_transaction: String {
      localize("sign_transaction_qr.signed_transaction")
    }
    /// Done
    public static var done: String {
      localize("sign_transaction_qr.done")
    }
  }
  public enum SignOut {
    public enum Button {
      /// Sign Out
      public static var title: String {
        localize("sign_out.button.title")
      }
    }
    public enum Alert {
      /// Sign Out?
      public static var title: String {
        localize("sign_out.alert.title")
      }
      /// This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase.
      public static var caption: String {
        localize("sign_out.alert.caption")
      }
      public enum Button {
        /// Sign Out
        public static var sign_out: String {
          localize("sign_out.alert.button.sign_out")
        }
      }
    }
  }
}
public enum TKLocales {
  public enum Actions {
    /// Copied
    public static var copied: String {
      localize("actions.copied")
    }
    /// Delete
    public static var delete: String {
      localize("actions.delete")
    }
    /// Cancel
    public static var cancel: String {
      localize("actions.cancel")
    }
    /// Save
    public static var save: String {
      localize("actions.save")
    }
    /// Paste
    public static var paste: String {
      localize("actions.paste")
    }
    /// Continue
    public static var continue_action: String {
      localize("actions.continue_action")
    }
    /// Done
    public static var done: String {
      localize("actions.done")
    }
    /// Edit
    public static var edit: String {
      localize("actions.edit")
    }
    /// Copy
    public static var copy: String {
      localize("actions.copy")
    }
    /// Sign Out
    public static var sign_out: String {
      localize("actions.sign_out")
    }
    /// More
    public static var more: String {
      localize("actions.more")
    }
  }
  public enum Errors {
    /// Error
    public static var unknown: String {
      localize("errors.unknown")
    }
  }
  public enum Dates {
    /// Today
    public static var today: String {
      localize("dates.today")
    }
    /// Yesterday
    public static var yesterday: String {
      localize("dates.yesterday")
    }
  }
  public enum Tabs {
    /// Wallet
    public static var wallet: String {
      localize("tabs.wallet")
    }
    /// History
    public static var history: String {
      localize("tabs.history")
    }
    /// Browser
    public static var browser: String {
      localize("tabs.browser")
    }
    /// Purchases
    public static var purchases: String {
      localize("tabs.purchases")
    }
  }
  public enum List {
    /// Show all
    public static var show_all: String {
      localize("list.show_all")
    }
    /// Hide
    public static var hide: String {
      localize("list.hide")
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
  public enum Purchases {
    /// Purchases
    public static var title: String {
      localize("purchases.title")
    }
    /// Your collectibles\nwill be shown here
    public static var empty_placeholder: String {
      localize("purchases.empty_placeholder")
    }
    /// Unnamed collection
    public static var unnamed_collection: String {
      localize("purchases.unnamed_collection")
    }
    /// Unverified
    public static var unverified: String {
      localize("purchases.unverified")
    }
  }
  public enum History {
    /// History
    public static var title: String {
      localize("history.title")
    }
    public enum Placeholder {
      /// Your history\nwill be shown here
      public static var title: String {
        localize("history.placeholder.title")
      }
      /// Make your first transaction!
      public static var subtitle: String {
        localize("history.placeholder.subtitle")
      }
      public enum Buttons {
        /// Receive
        public static var receive: String {
          localize("history.placeholder.buttons.receive")
        }
        /// Buy Toncoin
        public static var buy: String {
          localize("history.placeholder.buttons.buy")
        }
      }
    }
  }
  public enum Browser {
    public enum Tab {
      /// Explore
      public static var explore: String {
        localize("browser.tab.explore")
      }
      /// Connected
      public static var connected: String {
        localize("browser.tab.connected")
      }
    }
    public enum List {
      /// All
      public static var all: String {
        localize("browser.list.all")
      }
    }
    public enum SearchField {
      /// Search or enter address
      public static var placeholder: String {
        localize("browser.search_field.placeholder")
      }
    }
    public enum Search {
      /// Browser
      public static var title: String {
        localize("browser.search.title")
      }
      /// Enter an address or search the web
      public static var placeholder: String {
        localize("browser.search.placeholder")
      }
    }
  }
  public enum EventDetails {
    /// Received
    public static var received: String {
      localize("event_details.received")
    }
    /// Sent
    public static var sent: String {
      localize("event_details.sent")
    }
    /// Recipient
    public static var recipient: String {
      localize("event_details.recipient")
    }
    /// Sender
    public static var sender: String {
      localize("event_details.sender")
    }
    /// Fee
    public static var fee: String {
      localize("event_details.fee")
    }
    /// Comment
    public static var comment: String {
      localize("event_details.comment")
    }
    /// Sender address
    public static var sender_address: String {
      localize("event_details.sender_address")
    }
    /// Recipient address
    public static var recipient_address: String {
      localize("event_details.recipient_address")
    }
    /// Sent on %@
    public static func sent_on(_ p0: Any) -> String {
      return localizeWithArgs("event_details.sent_on", String(describing: p0))
    }
    /// Received on %@
    public static func received_on(_ p0: Any) -> String {
      return localizeWithArgs("event_details.received_on", String(describing: p0))
    }
    /// Transaction
    public static var transaction: String {
      localize("event_details.transaction")
    }
  }
  public enum Settings {
    /// Settings
    public static var title: String {
      localize("settings.title")
    }
    public enum Items {
      /// Security
      public static var security: String {
        localize("settings.items.security")
      }
      /// Backup
      public static var backup: String {
        localize("settings.items.backup")
      }
      /// Currency
      public static var currency: String {
        localize("settings.items.currency")
      }
      /// Theme
      public static var theme: String {
        localize("settings.items.theme")
      }
      /// Sign out
      public static var logout: String {
        localize("settings.items.logout")
      }
      /// FAQ
      public static var faq: String {
        localize("settings.items.faq")
      }
      /// Support
      public static var support: String {
        localize("settings.items.support")
      }
      /// Tonkeeper news
      public static var tk_news: String {
        localize("settings.items.tk_news")
      }
      /// Contact us
      public static var contact_us: String {
        localize("settings.items.contact_us")
      }
      /// Rate %@
      public static func rate(_ p0: Any) -> String {
        return localizeWithArgs("settings.items.rate", String(describing: p0))
      }
      /// Legal
      public static var legal: String {
        localize("settings.items.legal")
      }
      /// Delete 
      public static var delete_account: String {
        localize("settings.items.delete_account")
      }
      /// Delete Watch account
      public static var delete_watch_only: String {
        localize("settings.items.delete_watch_only")
      }
      /// Delete account
      public static var delete_acount_alert_title: String {
        localize("settings.items.delete_acount_alert_title")
      }
      /// Edit name and color
      public static var setup_wallet_description: String {
        localize("settings.items.setup_wallet_description")
      }
      /// Purchases
      public static var purchases: String {
        localize("settings.items.purchases")
      }
      /// Notifications
      public static var notifications: String {
        localize("settings.items.notifications")
      }
    }
    public enum Logout {
      /// Log out?
      public static var title: String {
        localize("settings.logout.title")
      }
      /// This will erase keys to the wallets. Make sure you have backed up your secret recovery phrases.
      public static var description: String {
        localize("settings.logout.description")
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
    public enum Purchases {
      /// Purchases
      public static var title: String {
        localize("settings.purchases.title")
      }
      public enum Sections {
        /// Visible
        public static var visible: String {
          localize("settings.purchases.sections.visible")
        }
        /// Hidden
        public static var hidden: String {
          localize("settings.purchases.sections.hidden")
        }
        /// Spam
        public static var spam: String {
          localize("settings.purchases.sections.spam")
        }
      }
      public enum Token {
        /// Unnamed collection
        public static var unnamed_collection: String {
          localize("settings.purchases.token.unnamed_collection")
        }
        /// Single token
        public static var single_token: String {
          localize("settings.purchases.token.single_token")
        }
        public enum TokenCount {
          /// tokens
          public static var zero: String {
            localize("settings.purchases.token.token_count.zero")
          }
          /// token
          public static var one: String {
            localize("settings.purchases.token.token_count.one")
          }
          /// tokens
          public static var few: String {
            localize("settings.purchases.token.token_count.few")
          }
          /// tokens
          public static var many: String {
            localize("settings.purchases.token.token_count.many")
          }
          /// tokens
          public static var other: String {
            localize("settings.purchases.token.token_count.other")
          }
        }
      }
      public enum Details {
        public enum Title {
          /// Token details
          public static var single_token: String {
            localize("settings.purchases.details.title.single_token")
          }
          /// Collection details
          public static var collection: String {
            localize("settings.purchases.details.title.collection")
          }
        }
        public enum Button {
          /// Hide token from wallet
          public static var hide_token: String {
            localize("settings.purchases.details.button.hide_token")
          }
          /// Show token in wallet
          public static var show_token: String {
            localize("settings.purchases.details.button.show_token")
          }
          /// Hide collection from wallet
          public static var hide_collection: String {
            localize("settings.purchases.details.button.hide_collection")
          }
          /// Show collection in wallet
          public static var show_collection: String {
            localize("settings.purchases.details.button.show_collection")
          }
          /// Not Spam
          public static var not_spam: String {
            localize("settings.purchases.details.button.not_spam")
          }
        }
        public enum Items {
          /// Name
          public static var name: String {
            localize("settings.purchases.details.items.name")
          }
          /// Collection ID
          public static var collection_id: String {
            localize("settings.purchases.details.items.collection_id")
          }
          /// Token ID
          public static var token_id: String {
            localize("settings.purchases.details.items.token_id")
          }
        }
      }
    }
    public enum Notifications {
      /// Notifications
      public static var title: String {
        localize("settings.notifications.title")
      }
      public enum NotificationsItem {
        /// Push notifications
        public static var title: String {
          localize("settings.notifications.notifications_item.title")
        }
        /// Get notifications when you receive TON, tokens and NFTs. Notifications from connected apps.
        public static var caption: String {
          localize("settings.notifications.notifications_item.caption")
        }
      }
    }
  }
  public enum Theme {
    /// Theme
    public static var title: String {
      localize("theme.title")
    }
    public enum Options {
      /// System
      public static var system: String {
        localize("theme.options.system")
      }
      /// Dark
      public static var dark: String {
        localize("theme.options.dark")
      }
      /// Blue
      public static var blue: String {
        localize("theme.options.blue")
      }
    }
  }
  public enum Currency {
    /// Primary currency
    public static var title: String {
      localize("currency.title")
    }
    public enum Items {
      /// Japanese Yen
      public static var jpy: String {
        localize("currency.items.jpy")
      }
      /// United States Dollar
      public static var usd: String {
        localize("currency.items.usd")
      }
      /// Euro
      public static var eur: String {
        localize("currency.items.eur")
      }
      /// Russian Ruble
      public static var rub: String {
        localize("currency.items.rub")
      }
      /// United Arab Emirates Dirham
      public static var aed: String {
        localize("currency.items.aed")
      }
      /// Kazakhstani Tenge
      public static var kzt: String {
        localize("currency.items.kzt")
      }
      /// Ukrainian hryvnian
      public static var uah: String {
        localize("currency.items.uah")
      }
      /// Great Britain Pound
      public static var gbp: String {
        localize("currency.items.gbp")
      }
      /// Swiss Franc
      public static var chf: String {
        localize("currency.items.chf")
      }
      /// China Yuan
      public static var cny: String {
        localize("currency.items.cny")
      }
      /// South Korean Won
      public static var krw: String {
        localize("currency.items.krw")
      }
      /// Indonesian Rupiah
      public static var idr: String {
        localize("currency.items.idr")
      }
      /// Indian Rupee
      public static var inr: String {
        localize("currency.items.inr")
      }
    }
  }
  public enum Backup {
    /// Backup
    public static var title: String {
      localize("backup.title")
    }
    public enum Information {
      /// Manual
      public static var title: String {
        localize("backup.information.title")
      }
      /// Back up your wallet manually by writing down the recovery phrase.
      public static var subtitle: String {
        localize("backup.information.subtitle")
      }
    }
    public enum Done {
      /// Manual Backup On
      public static var title: String {
        localize("backup.done.title")
      }
      /// Last backup %@
      public static func subtitle(_ p0: Any) -> String {
        return localizeWithArgs("backup.done.subtitle", String(describing: p0))
      }
    }
    public enum Manually {
      /// Back Up Manually
      public static var button: String {
        localize("backup.manually.button")
      }
    }
    public enum ShowPhrase {
      /// Show Recovery Phrase
      public static var title: String {
        localize("backup.show_phrase.title")
      }
    }
    public enum Warning {
      /// Attention
      public static var title: String {
        localize("backup.warning.title")
      }
      /// Please read the following carefully before viewing your recovery phrase.
      public static var caption: String {
        localize("backup.warning.caption")
      }
      public enum List {
        /// Never enter your recovery phrase any other place than Tonkeeper to access your wallet.
        public static var item1: String {
          localize("backup.warning.list.item1")
        }
        /// Tonkeeper Support never asks for a recovery phrase.
        public static var item2: String {
          localize("backup.warning.list.item2")
        }
        /// Everybody with your recovery phrase can access your wallet.
        public static var item3: String {
          localize("backup.warning.list.item3")
        }
      }
    }
  }
  public enum Security {
    /// Security
    public static var title: String {
      localize("security.title")
    }
    /// Use %@
    public static func use(_ p0: Any) -> String {
      return localizeWithArgs("security.use", String(describing: p0))
    }
    /// Change Passcode
    public static var change_passcode: String {
      localize("security.change_passcode")
    }
    /// Biometry unavailable
    public static var unavailable_error: String {
      localize("security.unavailable_error")
    }
    /// You can always unlock your wallet with a passcode.
    public static var use_biometry_description: String {
      localize("security.use_biometry_description")
    }
    /// Lock Screen
    public static var lock_screen: String {
      localize("security.lock_screen")
    }
    /// Require passcode to view wallet contents.
    public static var lock_screen_description: String {
      localize("security.lock_screen_description")
    }
  }
  public enum WalletButtons {
    /// Send
    public static var send: String {
      localize("wallet_buttons.send")
    }
    /// Receive
    public static var receive: String {
      localize("wallet_buttons.receive")
    }
    /// Scan
    public static var scan: String {
      localize("wallet_buttons.scan")
    }
    /// Buy TON
    public static var buy: String {
      localize("wallet_buttons.buy")
    }
    /// Swap
    public static var swap: String {
      localize("wallet_buttons.swap")
    }
    /// Stake
    public static var stake: String {
      localize("wallet_buttons.stake")
    }
  }
  public enum Send {
    /// Send
    public static var title: String {
      localize("send.title")
    }
    public enum Recepient {
      /// Address or name
      public static var placeholder: String {
        localize("send.recepient.placeholder")
      }
    }
    public enum Amount {
      /// Amount
      public static var placeholder: String {
        localize("send.amount.placeholder")
      }
    }
    public enum Comment {
      /// Comment
      public static var placeholder: String {
        localize("send.comment.placeholder")
      }
      /// Will be visible to everyone.
      public static var description: String {
        localize("send.comment.description")
      }
      /// Use only ASCII characters: digits, latin alphabet letters and punctuation marks.
      public static var ascii_error: String {
        localize("send.comment.ascii_error")
      }
    }
    public enum RequiredComment {
      /// Required comment
      public static var placeholder: String {
        localize("send.required_comment.placeholder")
      }
      /// You must include the note from the exchange for transfer. Without it your funds will be lost.
      public static var description: String {
        localize("send.required_comment.description")
      }
    }
  }
  public enum ConfirmSend {
    public enum TokenTransfer {
      /// Confirm action
      public static var title: String {
        localize("confirm_send.token_transfer.title")
      }
      /// Transfer %@
      public static func transfer(_ p0: Any) -> String {
        return localizeWithArgs("confirm_send.token_transfer.transfer", String(describing: p0))
      }
    }
    /// Fee
    public static var fee: String {
      localize("confirm_send.fee")
    }
    /// Wallet
    public static var wallet: String {
      localize("confirm_send.wallet")
    }
    /// Amount
    public static var amount: String {
      localize("confirm_send.amount")
    }
    /// Comment
    public static var comment: String {
      localize("confirm_send.comment")
    }
    public enum Recipient {
      /// Recipient
      public static var title: String {
        localize("confirm_send.recipient.title")
      }
      /// Recipient address
      public static var address: String {
        localize("confirm_send.recipient.address")
      }
    }
    /// Confirm and send
    public static var confirm_button: String {
      localize("confirm_send.confirm_button")
    }
  }
  public enum CustomizeWallet {
    /// Customize your Wallet
    public static var title: String {
      localize("customize_wallet.title")
    }
    /// Wallet name and icon are stored locally on your device.
    public static var description: String {
      localize("customize_wallet.description")
    }
    /// Wallet Name
    public static var input_placeholder: String {
      localize("customize_wallet.input_placeholder")
    }
    /// Wallet
    public static var default_wallet_name: String {
      localize("customize_wallet.default_wallet_name")
    }
  }
  public enum ConnectionStatus {
    /// Updating
    public static var updating: String {
      localize("connection_status.updating")
    }
    /// No Internet connection
    public static var no_internet: String {
      localize("connection_status.no_internet")
    }
    /// Updated %@
    public static func updated_at(_ p0: Any) -> String {
      return localizeWithArgs("connection_status.updated_at", String(describing: p0))
    }
  }
  public enum Token {
    /// Unverified token
    public static var unverified: String {
      localize("token.unverified")
    }
  }
  public enum Onboarding {
    /// Create a new wallet or add an existing one
    public static var caption: String {
      localize("onboarding.caption")
    }
    public enum Buttons {
      /// Create New Wallet
      public static var create_new: String {
        localize("onboarding.buttons.create_new")
      }
      /// Import Existing Wallet
      public static var import_existing: String {
        localize("onboarding.buttons.import_existing")
      }
    }
  }
  public enum Passcode {
    /// Create passcode
    public static var create: String {
      localize("passcode.create")
    }
    /// Re-enter passcode
    public static var reenter: String {
      localize("passcode.reenter")
    }
    /// Enter passcode
    public static var enter: String {
      localize("passcode.enter")
    }
  }
  public enum ImportWallet {
    /// Enter recovery phrase
    public static var title: String {
      localize("import_wallet.title")
    }
    /// When you created this wallet, you got a 24-word recovery phrase. Enter it to restore access to your wallet.
    public static var description: String {
      localize("import_wallet.description")
    }
  }
  public enum ChooseWallets {
    /// Choose Wallets
    public static var title: String {
      localize("choose_wallets.title")
    }
    /// Choose wallets you want to add.
    public static var description: String {
      localize("choose_wallets.description")
    }
    /// tokens
    public static var tokens: String {
      localize("choose_wallets.tokens")
    }
    /// Already added
    public static var alreadyAdded: String {
      localize("choose_wallets.alreadyAdded")
    }
  }
  public enum FinishSetup {
    /// Finish setting up
    public static var title: String {
      localize("finish_setup.title")
    }
    /// Use %@ to approve transactions
    public static func setup_biometry(_ p0: Any) -> String {
      return localizeWithArgs("finish_setup.setup_biometry", String(describing: p0))
    }
    /// Biometry unavailable
    public static var biometry_unavailable: String {
      localize("finish_setup.biometry_unavailable")
    }
    /// Back up the wallet recovery phrase
    public static var backup: String {
      localize("finish_setup.backup")
    }
  }
  public enum WalletsList {
    /// Wallets list
    public static var title: String {
      localize("wallets_list.title")
    }
    /// Add Wallet
    public static var add_wallet: String {
      localize("wallets_list.add_wallet")
    }
  }
  public enum AddWallet {
    /// Add Wallet
    public static var title: String {
      localize("add_wallet.title")
    }
    /// Create a new wallet or add an existing one.
    public static var description: String {
      localize("add_wallet.description")
    }
    public enum Items {
      public enum NewWallet {
        /// New Wallet
        public static var title: String {
          localize("add_wallet.items.new_wallet.title")
        }
        /// Create new wallet
        public static var subtitle: String {
          localize("add_wallet.items.new_wallet.subtitle")
        }
      }
      public enum ExistingWallet {
        /// Existing Wallet
        public static var title: String {
          localize("add_wallet.items.existing_wallet.title")
        }
        /// Import wallet with a 24 secret recovery words
        public static var subtitle: String {
          localize("add_wallet.items.existing_wallet.subtitle")
        }
      }
      public enum WatchOnly {
        /// Watch Account
        public static var title: String {
          localize("add_wallet.items.watch_only.title")
        }
        /// For monitor wallet activity without recovery phrase
        public static var subtitle: String {
          localize("add_wallet.items.watch_only.subtitle")
        }
      }
      public enum Testnet {
        /// Testnet Account
        public static var title: String {
          localize("add_wallet.items.testnet.title")
        }
        /// Import wallet with a 24 secret recovery words to Testnet
        public static var subtitle: String {
          localize("add_wallet.items.testnet.subtitle")
        }
      }
      public enum PairSigner {
        /// Pair Signer
        public static var title: String {
          localize("add_wallet.items.pair_signer.title")
        }
        /// A higher level of control and security
        public static var subtitle: String {
          localize("add_wallet.items.pair_signer.subtitle")
        }
      }
      public enum PairLedger {
        /// Pair with Ledger
        public static var title: String {
          localize("add_wallet.items.pair_ledger.title")
        }
        /// Hardware module, Bluetooth, limited TON features
        public static var subtitle: String {
          localize("add_wallet.items.pair_ledger.subtitle")
        }
      }
    }
  }
  public enum Scanner {
    /// Scan QR code
    public static var title: String {
      localize("scanner.title")
    }
  }
  public enum Signer {
    public enum Scan {
      /// Open Signer » Select the required key » Scan QR code
      public static var subtitle: String {
        localize("signer.scan.subtitle")
      }
      /// Open Signer on this device
      public static var open_signer_button: String {
        localize("signer.scan.open_signer_button")
      }
    }
  }
  public enum Chart {
    /// Price
    public static var price: String {
      localize("chart.price")
    }
  }
  public enum Periods {
    /// H
    public static var hour: String {
      localize("periods.hour")
    }
    /// D
    public static var day: String {
      localize("periods.day")
    }
    /// W
    public static var week: String {
      localize("periods.week")
    }
    /// M
    public static var month: String {
      localize("periods.month")
    }
    /// 6M
    public static var half_year: String {
      localize("periods.half_year")
    }
    /// Y
    public static var year: String {
      localize("periods.year")
    }
  }
  public enum WalletTags {
    /// Watch only
    public static var watch_only: String {
      localize("wallet_tags.watch_only")
    }
  }
  public enum BalanceHeader {
    /// Your address: 
    public static var your_address: String {
      localize("balance_header.your_address")
    }
  }
  public enum BalanceList {
    public enum StakingItem {
      /// Staked
      public static var title: String {
        localize("balance_list.staking_item.title")
      }
      public enum Comment {
        /// %@ TON ready.\nTap to collect.
        public static func ready(_ p0: Any) -> String {
          return localizeWithArgs("balance_list.staking_item.comment.ready", String(describing: p0))
        }
        /// %@ TON staked
        public static func staked(_ p0: Any) -> String {
          return localizeWithArgs("balance_list.staking_item.comment.staked", String(describing: p0))
        }
        /// %@ TON unstaked
        public static func unstaked(_ p0: Any) -> String {
          return localizeWithArgs("balance_list.staking_item.comment.unstaked", String(describing: p0))
        }
        /// in %@
        public static func time_estimate(_ p0: Any) -> String {
          return localizeWithArgs("balance_list.staking_item.comment.time_estimate", String(describing: p0))
        }
      }
    }
  }
  public enum Receive {
    /// Receive %@
    public static func title(_ p0: Any) -> String {
      return localizeWithArgs("receive.title", String(describing: p0))
    }
    /// Send only %@ and tokens in TON network to this address, or you might lose your funds.
    public static func description(_ p0: Any) -> String {
      return localizeWithArgs("receive.description", String(describing: p0))
    }
  }
  public enum WatchAccount {
    /// Watch Account
    public static var title: String {
      localize("watch_account.title")
    }
    /// Monitor wallet activity without recovery phrase. You will be notified of any transactions from this wallet.
    public static var description: String {
      localize("watch_account.description")
    }
    /// Address or name
    public static var placeholder: String {
      localize("watch_account.placeholder")
    }
  }
  public enum ActionTypes {
    public enum Future {
      /// Send
      public static var send: String {
        localize("action_types.future.send")
      }
      /// Receive
      public static var receive: String {
        localize("action_types.future.receive")
      }
    }
    /// Sent
    public static var sent: String {
      localize("action_types.sent")
    }
    /// Received
    public static var received: String {
      localize("action_types.received")
    }
    /// Stake
    public static var stake: String {
      localize("action_types.stake")
    }
    /// Unstake
    public static var unstake: String {
      localize("action_types.unstake")
    }
    /// Unstake Request
    public static var unstake_request: String {
      localize("action_types.unstake_request")
    }
    /// Swap
    public static var swap: String {
      localize("action_types.swap")
    }
    /// Spam
    public static var spam: String {
      localize("action_types.spam")
    }
    /// Bounced
    public static var bounced: String {
      localize("action_types.bounced")
    }
    /// Subscribed
    public static var subscribed: String {
      localize("action_types.subscribed")
    }
    /// Unsubscribed
    public static var unsubscribed: String {
      localize("action_types.unsubscribed")
    }
    /// Call contract
    public static var contract_exec: String {
      localize("action_types.contract_exec")
    }
    /// NFT сollection creation
    public static var nft_collection_deploy: String {
      localize("action_types.nft_collection_deploy")
    }
    /// NFT creation
    public static var nft_deploy: String {
      localize("action_types.nft_deploy")
    }
    /// Removal from sale
    public static var nft_sale_removal: String {
      localize("action_types.nft_sale_removal")
    }
    /// NFT purchase
    public static var nft_purchase: String {
      localize("action_types.nft_purchase")
    }
    /// Bid
    public static var bid: String {
      localize("action_types.bid")
    }
    /// Put up for auction
    public static var put_up_auction: String {
      localize("action_types.put_up_auction")
    }
    /// End of auction
    public static var end_auction: String {
      localize("action_types.end_auction")
    }
    /// Renew Domain
    public static var domain_renew: String {
      localize("action_types.domain_renew")
    }
    /// Unknown
    public static var unknown: String {
      localize("action_types.unknown")
    }
    /// Wallet initialized
    public static var wallet_initialize: String {
      localize("action_types.wallet_initialize")
    }
  }
  public enum LedgerConnect {
    /// Connect Ledger
    public static var title: String {
      localize("ledger_connect.title")
    }
    public enum Steps {
      public enum BluetoothConnect {
        /// Connect Ledger to your device via Bluetooth
        public static var description: String {
          localize("ledger_connect.steps.bluetooth_connect.description")
        }
      }
      public enum TonApp {
        /// Unlock it and open TON App
        public static var description: String {
          localize("ledger_connect.steps.ton_app.description")
        }
        /// Install TON App
        public static var link: String {
          localize("ledger_connect.steps.ton_app.link")
        }
      }
    }
  }
  public enum LedgerConfirm {
    /// Confirm Action
    public static var title: String {
      localize("ledger_confirm.title")
    }
    public enum Steps {
      public enum BluetoothConnect {
        /// Connect Ledger to your device via Bluetooth
        public static var description: String {
          localize("ledger_confirm.steps.bluetooth_connect.description")
        }
      }
      public enum TonApp {
        /// Unlock it and open TON App
        public static var description: String {
          localize("ledger_confirm.steps.ton_app.description")
        }
      }
      public enum Confirm {
        /// Confirm your transaction on Ledger
        public static var description: String {
          localize("ledger_confirm.steps.confirm.description")
        }
      }
    }
  }
  public enum Bluetooth {
    public enum PermissionsAlert {
      /// Bluetooth Permissions
      public static var title: String {
        localize("bluetooth.permissions_alert.title")
      }
      /// Please enable Bluetooth permissions in your settings to use this feature
      public static var message: String {
        localize("bluetooth.permissions_alert.message")
      }
      /// Open Settings
      public static var open_settings: String {
        localize("bluetooth.permissions_alert.open_settings")
      }
    }
    public enum PoweredOffAlert {
      /// Bluetooth is off
      public static var title: String {
        localize("bluetooth.powered_off_alert.title")
      }
      /// Please turn on Bluetooth to use this feature
      public static var message: String {
        localize("bluetooth.powered_off_alert.message")
      }
      /// Open Settings
      public static var open_settings: String {
        localize("bluetooth.powered_off_alert.open_settings")
      }
    }
  }
  public enum SignOutFull {
    /// 🚧 🚨🚨🚨 🚧\nSign Out of All Wallets?
    public static var title: String {
      localize("sign_out_full.title")
    }
    /// This will erase keys to all wallets. Make sure you have backed up your recovery phrases.
    public static var description: String {
      localize("sign_out_full.description")
    }
  }
  public enum SignOutWarning {
    /// Sign Out
    public static var title: String {
      localize("sign_out_warning.title")
    }
    /// Wallet keys will be erased from this device.
    public static var caption: String {
      localize("sign_out_warning.caption")
    }
    /// I have a backup copy of the recovery phrase for 
    public static var tick_description: String {
      localize("sign_out_warning.tick_description")
    }
    /// Back up
    public static var tick_back_up: String {
      localize("sign_out_warning.tick_back_up")
    }
  }
  public enum HomeScreenConfiguration {
    /// Home Screen
    public static var title: String {
      localize("home_screen_configuration.title")
    }
    public enum Sections {
      /// Pinned
      public static var pinned: String {
        localize("home_screen_configuration.sections.pinned")
      }
      /// All Assets
      public static var all_assets: String {
        localize("home_screen_configuration.sections.all_assets")
      }
      /// Sorted by Price
      public static var sorted_by_price: String {
        localize("home_screen_configuration.sections.sorted_by_price")
      }
    }
  }
  public enum NftDetails {
    /// Single NFT
    public static var single_nft: String {
      localize("nft_details.single_nft")
    }
    /// Details
    public static var details: String {
      localize("nft_details.details")
    }
    /// View in explorer
    public static var view_in_explorer: String {
      localize("nft_details.view_in_explorer")
    }
    /// Owner
    public static var owner: String {
      localize("nft_details.owner")
    }
    /// Expiration date
    public static var expiration_date: String {
      localize("nft_details.expiration_date")
    }
    /// Contract address
    public static var contract_address: String {
      localize("nft_details.contract_address")
    }
    /// Properties
    public static var properties: String {
      localize("nft_details.properties")
    }
    /// Transfer
    public static var transfer: String {
      localize("nft_details.transfer")
    }
    /// Linked with %@
    public static func linked_with(_ p0: Any) -> String {
      return localizeWithArgs("nft_details.linked_with", String(describing: p0))
    }
    /// Link domain
    public static var linked_domain: String {
      localize("nft_details.linked_domain")
    }
    /// Renew until %@
    public static func renew_until(_ p0: Any) -> String {
      return localizeWithArgs("nft_details.renew_until", String(describing: p0))
    }
    /// Expires in %@ days
    public static func expires_in_days(_ p0: Any) -> String {
      return localizeWithArgs("nft_details.expires_in_days", String(describing: p0))
    }
    /// Unverified NFT
    public static var unverified_nft: String {
      localize("nft_details.unverified_nft")
    }
    /// About collection
    public static var about_collection: String {
      localize("nft_details.about_collection")
    }
    /// Domain is on sale at the marketplace now. For transfer, you should remove it from sale first.
    public static var domain_on_sale_description: String {
      localize("nft_details.domain_on_sale_description")
    }
    /// NFT is on sale at the marketplace now. For transfer, you should remove it from sale first.
    public static var nft_on_sale_description: String {
      localize("nft_details.nft_on_sale_description")
    }
  }
  public enum BuyListPopup {
    /// Do not show again
    public static var do_not_show_again: String {
      localize("buy_list_popup.do_not_show_again")
    }
    /// You are opening an external app not operated by Tonkeeper.
    public static var you_are_opening_external_app: String {
      localize("buy_list_popup.you_are_opening_external_app")
    }
  }
  public enum UglyBuyList {
    /// Buy
    public static var buy: String {
      localize("ugly_buy_list.buy")
    }
  }
  public enum SettingsListNotificationsConfigurator {
    /// Apps
    public static var connectedAppsTitle: String {
      localize("settings_list_notifications_configurator.connectedAppsTitle")
    }
    /// Notifications from connected apps in your activity
    public static var connectedAppsSectionCaption: String {
      localize("settings_list_notifications_configurator.connectedAppsSectionCaption")
    }
  }
  public enum SettingsListSecurityConfigurator {
    /// Face ID
    public static var face_id: String {
      localize("settings_list_security_configurator.face_id")
    }
    /// Touch ID
    public static var touch_id: String {
      localize("settings_list_security_configurator.touch_id")
    }
  }
  public enum SignerSign {
    /// Step 1
    public static var step_one: String {
      localize("signer_sign.step_one")
    }
    /// Scan the QR code with Signer
    public static var step_one_description: String {
      localize("signer_sign.step_one_description")
    }
    /// Step 2
    public static var step_two: String {
      localize("signer_sign.step_two")
    }
    /// Confirm your transaction in Signer
    public static var step_two_description: String {
      localize("signer_sign.step_two_description")
    }
    /// Step 3
    public static var step_three: String {
      localize("signer_sign.step_three")
    }
    /// Scan signed transaction QR code from Signer
    public static var step_three_description: String {
      localize("signer_sign.step_three_description")
    }
    /// Transaction
    public static var transaction: String {
      localize("signer_sign.transaction")
    }
  }
  /// APY
  public static var apy: String {
    localize("apy")
  }
  /// MAX APY
  public static var max_apy: String {
    localize("max_apy")
  }
  public enum StakingList {
    /// Minimal Deposit
    public static var minimal_deposit: String {
      localize("staking_list.minimal_deposit")
    }
    /// MAX APY
    public static var max_apy: String {
      localize("staking_list.max_apy")
    }
    /// APY
    public static var apy: String {
      localize("staking_list.apy")
    }
    /// Minimum deposit %@
    public static func minimum_deposit_description(_ p0: Any) -> String {
      return localizeWithArgs("staking_list.minimum_deposit_description", String(describing: p0))
    }
  }
  public enum StakingBalanceDetails {
    /// Minimal Deposit
    public static var minimal_deposit: String {
      localize("staking_balance_details.minimal_deposit")
    }
    /// Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.
    public static var description: String {
      localize("staking_balance_details.description")
    }
    /// When you stake TON in a Tonstakers pool, you receive a token called tsTON that represents your share in the pool. As the pool accumulates profits, your tsTON represents larger amount of TON.
    public static var jetton_button_description: String {
      localize("staking_balance_details.jetton_button_description")
    }
    /// Pending Stake
    public static var pending_stake: String {
      localize("staking_balance_details.pending_stake")
    }
    /// Pending Unstake
    public static var pending_unstake: String {
      localize("staking_balance_details.pending_unstake")
    }
    /// Unstake ready
    public static var unstake_ready: String {
      localize("staking_balance_details.unstake_ready")
    }
    /// after the end of the cycle
    public static var after_end_of_cycle: String {
      localize("staking_balance_details.after_end_of_cycle")
    }
    /// Tap to collect
    public static var tap_to_collect: String {
      localize("staking_balance_details.tap_to_collect")
    }
    /// Stake
    public static var stake: String {
      localize("staking_balance_details.stake")
    }
    /// Unstake
    public static var unstake: String {
      localize("staking_balance_details.unstake")
    }
  }
  public enum StakingConfirmationMapper {
    /// Wallet
    public static var wallet: String {
      localize("staking_confirmation_mapper.wallet")
    }
    /// Recipient
    public static var recipient: String {
      localize("staking_confirmation_mapper.recipient")
    }
    /// Amount
    public static var amount: String {
      localize("staking_confirmation_mapper.amount")
    }
    /// APY
    public static var apy: String {
      localize("staking_confirmation_mapper.apy")
    }
    /// Fee
    public static var fee: String {
      localize("staking_confirmation_mapper.fee")
    }
    /// Stake
    public static var stake: String {
      localize("staking_confirmation_mapper.stake")
    }
    /// Confirm action
    public static var confirm_action: String {
      localize("staking_confirmation_mapper.confirm_action")
    }
  }
  public enum StakingDepositInput {
    /// Liquid Staking
    public static var liquid_staking: String {
      localize("staking_deposit_input.liquid_staking")
    }
    /// Other
    public static var other: String {
      localize("staking_deposit_input.other")
    }
    /// Continue
    public static var continue_title: String {
      localize("staking_deposit_input.continue_title")
    }
    /// Options
    public static var options: String {
      localize("staking_deposit_input.options")
    }
  }
  public enum StakingDepositPoolPicker {
    /// MAX APY
    public static var max_apy: String {
      localize("staking_deposit_pool_picker.max_apy")
    }
    /// APY
    public static var apy: String {
      localize("staking_deposit_pool_picker.apy")
    }
    /// Options
    public static var options: String {
      localize("staking_deposit_pool_picker.options")
    }
    /// Liquid Staking
    public static var liquid_staking: String {
      localize("staking_deposit_pool_picker.liquid_staking")
    }
    /// Other
    public static var other: String {
      localize("staking_deposit_pool_picker.other")
    }
  }
  public enum StakingPoolDetails {
    /// MAX APY
    public static var max_apy: String {
      localize("staking_pool_details.max_apy")
    }
    /// APY
    public static var apy: String {
      localize("staking_pool_details.apy")
    }
    /// Minimal Deposit
    public static var minimal_deposit: String {
      localize("staking_pool_details.minimal_deposit")
    }
    /// Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.
    public static var description: String {
      localize("staking_pool_details.description")
    }
  }
  public enum TonConnectMapper {
    /// Connect to 
    public static var connect_to: String {
      localize("ton_connect_mapper.connect_to")
    }
    /// %@ is requesting access to your wallet address%@
    public static func requesting_capture(_ p0: Any, _ p1: Any) -> String {
      return localizeWithArgs("ton_connect_mapper.requesting_capture", String(describing: p0), String(describing: p1))
    }
  }
  public enum TonConnect {
    /// Connect wallet
    public static var connect_wallet: String {
      localize("ton_connect.connect_wallet")
    }
    /// Be sure to check the service address before connecting the wallet.
    public static var sure_check_service_address: String {
      localize("ton_connect.sure_check_service_address")
    }
  }
  public enum WalletBalanceList {
    /// Join Tonkeeper channel
    public static var join_channel: String {
      localize("wallet_balance_list.join_channel")
    }
    /// Enable transaction notifications
    public static var transaction_notifications: String {
      localize("wallet_balance_list.transaction_notifications")
    }
  }
}
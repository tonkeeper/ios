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
    /// Purchases
    public static var purchases: String {
      localize("tabs.purchases")
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
  }
  public enum History {
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
    /// History
    public static var title: String {
      localize("history.title")
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
      /// Rate Tonkeeper X
      public static var rate: String {
        localize("settings.items.rate")
      }
      /// Legal
      public static var legal: String {
        localize("settings.items.legal")
      }
      /// Delete account
      public static var delete_account: String {
        localize("settings.items.delete_account")
      }
      /// Edit name and color
      public static var setup_wallet_description: String {
        localize("settings.items.setup_wallet_description")
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
    /// Buy or Sell
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
  public enum Buy {
    /// Buy
    public static var button_buy: String {
      localize("buy.button_buy")
    }
    /// Sell
    public static var button_sell: String {
      localize("buy.button_sell")
    }
    /// Min. amount: %@
    public static func min_amount(_ p0: Any) -> String {
      return localizeWithArgs("buy.min_amount", String(describing: p0))
    }
    /// %@ %@ for 1 TON
    public static func rate(_ p0: Any, _ p1: Any) -> String {
      return localizeWithArgs("buy.rate", String(describing: p0), String(describing: p1))
    }
    /// You pay
    public static var you_pay: String {
      localize("buy.you_pay")
    }
    /// You get
    public static var you_get: String {
      localize("buy.you_get")
    }
    /// Operator
    public static var transaction_operator: String {
      localize("buy.transaction_operator")
    }
    /// Service provided by %@
    public static func service_provider(_ p0: Any) -> String {
      return localizeWithArgs("buy.service_provider", String(describing: p0))
    }
  }
}
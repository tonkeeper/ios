// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum TKLocales {
  /// APY
  public static let apy = TKLocales.tr("Localizable", "apy", fallback: "APY")
  /// MAX APY
  public static let maxApy = TKLocales.tr("Localizable", "max_apy", fallback: "MAX APY")
  public enum ActionTypes {
    /// Bid
    public static let bid = TKLocales.tr("Localizable", "action_types.bid", fallback: "Bid")
    /// Bounced
    public static let bounced = TKLocales.tr("Localizable", "action_types.bounced", fallback: "Bounced")
    /// Burned
    public static let burned = TKLocales.tr("Localizable", "action_types.burned", fallback: "Burned")
    /// Call contract
    public static let contractExec = TKLocales.tr("Localizable", "action_types.contract_exec", fallback: "Call contract")
    /// Renew Domain
    public static let domainRenew = TKLocales.tr("Localizable", "action_types.domain_renew", fallback: "Renew Domain")
    /// End of auction
    public static let endAuction = TKLocales.tr("Localizable", "action_types.end_auction", fallback: "End of auction")
    /// NFT сollection creation
    public static let nftCollectionDeploy = TKLocales.tr("Localizable", "action_types.nft_collection_deploy", fallback: "NFT сollection creation")
    /// NFT creation
    public static let nftDeploy = TKLocales.tr("Localizable", "action_types.nft_deploy", fallback: "NFT creation")
    /// NFT purchase
    public static let nftPurchase = TKLocales.tr("Localizable", "action_types.nft_purchase", fallback: "NFT purchase")
    /// Removal from sale
    public static let nftSaleRemoval = TKLocales.tr("Localizable", "action_types.nft_sale_removal", fallback: "Removal from sale")
    /// Put up for auction
    public static let putUpAuction = TKLocales.tr("Localizable", "action_types.put_up_auction", fallback: "Put up for auction")
    /// Received
    public static let received = TKLocales.tr("Localizable", "action_types.received", fallback: "Received")
    /// Sent
    public static let sent = TKLocales.tr("Localizable", "action_types.sent", fallback: "Sent")
    /// Spam
    public static let spam = TKLocales.tr("Localizable", "action_types.spam", fallback: "Spam")
    /// Stake
    public static let stake = TKLocales.tr("Localizable", "action_types.stake", fallback: "Stake")
    /// Subscribed
    public static let subscribed = TKLocales.tr("Localizable", "action_types.subscribed", fallback: "Subscribed")
    /// Swap
    public static let swap = TKLocales.tr("Localizable", "action_types.swap", fallback: "Swap")
    /// Unknown
    public static let unknown = TKLocales.tr("Localizable", "action_types.unknown", fallback: "Unknown")
    /// Unstake
    public static let unstake = TKLocales.tr("Localizable", "action_types.unstake", fallback: "Unstake")
    /// Unstake Request
    public static let unstakeRequest = TKLocales.tr("Localizable", "action_types.unstake_request", fallback: "Unstake Request")
    /// Unsubscribed
    public static let unsubscribed = TKLocales.tr("Localizable", "action_types.unsubscribed", fallback: "Unsubscribed")
    /// Wallet initialized
    public static let walletInitialize = TKLocales.tr("Localizable", "action_types.wallet_initialize", fallback: "Wallet initialized")
    public enum Future {
      /// Receive
      public static let receive = TKLocales.tr("Localizable", "action_types.future.receive", fallback: "Receive")
      /// Send
      public static let send = TKLocales.tr("Localizable", "action_types.future.send", fallback: "Send")
    }
  }
  public enum Actions {
    /// Burn NFT
    public static let burnNft = TKLocales.tr("Localizable", "actions.burn_nft", fallback: "Burn NFT")
    /// Cancel
    public static let cancel = TKLocales.tr("Localizable", "actions.cancel", fallback: "Cancel")
    /// Continue
    public static let continueAction = TKLocales.tr("Localizable", "actions.continue_action", fallback: "Continue")
    /// Copy
    public static let copy = TKLocales.tr("Localizable", "actions.copy", fallback: "Copy")
    /// Delete
    public static let delete = TKLocales.tr("Localizable", "actions.delete", fallback: "Delete")
    /// Done
    public static let done = TKLocales.tr("Localizable", "actions.done", fallback: "Done")
    /// Edit
    public static let edit = TKLocales.tr("Localizable", "actions.edit", fallback: "Edit")
    /// Hide and Report Spam
    public static let hideAndReportSpam = TKLocales.tr("Localizable", "actions.hide_and_report_spam", fallback: "Hide and Report Spam")
    /// Hide Collection
    public static let hideCollection = TKLocales.tr("Localizable", "actions.hide_collection", fallback: "Hide Collection")
    /// Hide NFT
    public static let hideNft = TKLocales.tr("Localizable", "actions.hide_nft", fallback: "Hide NFT")
    /// More
    public static let more = TKLocales.tr("Localizable", "actions.more", fallback: "More")
    /// OK
    public static let ok = TKLocales.tr("Localizable", "actions.ok", fallback: "OK")
    /// Open
    public static let `open` = TKLocales.tr("Localizable", "actions.open", fallback: "Open")
    /// Paste
    public static let paste = TKLocales.tr("Localizable", "actions.paste", fallback: "Paste")
    /// Save
    public static let save = TKLocales.tr("Localizable", "actions.save", fallback: "Save")
    /// Sign Out
    public static let signOut = TKLocales.tr("Localizable", "actions.sign_out", fallback: "Sign Out")
    /// View on Tonviewer
    public static let viewOnTonviewier = TKLocales.tr("Localizable", "actions.view_on_tonviewier", fallback: "View on Tonviewer")
  }
  public enum AddWallet {
    /// Create a new wallet or add an existing one.
    public static let description = TKLocales.tr("Localizable", "add_wallet.description", fallback: "Create a new wallet or add an existing one.")
    /// Add Wallet
    public static let title = TKLocales.tr("Localizable", "add_wallet.title", fallback: "Add Wallet")
    public enum Items {
      public enum ExistingWallet {
        /// Import wallet with a 24 secret recovery words
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.existing_wallet.subtitle", fallback: "Import wallet with a 24 secret recovery words")
        /// Existing Wallet
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.existing_wallet.title", fallback: "Existing Wallet")
      }
      public enum NewWallet {
        /// Create new wallet
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.new_wallet.subtitle", fallback: "Create new wallet")
        /// New Wallet
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.new_wallet.title", fallback: "New Wallet")
      }
      public enum PairKeystone {
        /// A high level of security with an AIR-GAP hardware wallet
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.pair_keystone.subtitle", fallback: "A high level of security with an AIR-GAP hardware wallet")
        /// Pair with Keystone
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.pair_keystone.title", fallback: "Pair with Keystone")
      }
      public enum PairLedger {
        /// Hardware module, Bluetooth, limited TON features
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.pair_ledger.subtitle", fallback: "Hardware module, Bluetooth, limited TON features")
        /// Pair with Ledger
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.pair_ledger.title", fallback: "Pair with Ledger")
      }
      public enum PairSigner {
        /// A higher level of control and security
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.pair_signer.subtitle", fallback: "A higher level of control and security")
        /// Pair Signer
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.pair_signer.title", fallback: "Pair Signer")
      }
      public enum Testnet {
        /// Import wallet with a 24 secret recovery words to Testnet
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.testnet.subtitle", fallback: "Import wallet with a 24 secret recovery words to Testnet")
        /// Testnet Account
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.testnet.title", fallback: "Testnet Account")
      }
      public enum WatchOnly {
        /// For monitor wallet activity without recovery phrase
        public static let subtitle = TKLocales.tr("Localizable", "add_wallet.items.watch_only.subtitle", fallback: "For monitor wallet activity without recovery phrase")
        /// Watch Account
        public static let title = TKLocales.tr("Localizable", "add_wallet.items.watch_only.title", fallback: "Watch Account")
      }
    }
  }
  public enum Backup {
    /// Backup
    public static let title = TKLocales.tr("Localizable", "backup.title", fallback: "Backup")
    public enum Balance {
      /// Your balance is %@, and it's only protected by a recovery phrase you haven't written down yet. Backup the phrase to avoid losing funds in case of device issues.
      public static func warning(_ p1: Any) -> String {
        return TKLocales.tr("Localizable", "backup.balance.warning", String(describing: p1), fallback: "Your balance is %@, and it's only protected by a recovery phrase you haven't written down yet. Backup the phrase to avoid losing funds in case of device issues.")
      }
    }
    public enum Check {
      /// Write down these words with their numbers and store them in a safe place.
      public static let caption = TKLocales.tr("Localizable", "backup.check.caption", fallback: "Write down these words with their numbers and store them in a safe place.")
      /// Recovery phrase
      public static let title = TKLocales.tr("Localizable", "backup.check.title", fallback: "Recovery phrase")
      public enum Button {
        /// Check Backup
        public static let title = TKLocales.tr("Localizable", "backup.check.button.title", fallback: "Check Backup")
      }
      public enum Input {
        /// Let's see if you've got everything right. Enter words %d, %d, and %d.
        public static func caption(_ p1: Int, _ p2: Int, _ p3: Int) -> String {
          return TKLocales.tr("Localizable", "backup.check.input.caption", p1, p2, p3, fallback: "Let's see if you've got everything right. Enter words %d, %d, and %d.")
        }
        /// Backup Check
        public static let title = TKLocales.tr("Localizable", "backup.check.input.title", fallback: "Backup Check")
        public enum Button {
          /// Done
          public static let title = TKLocales.tr("Localizable", "backup.check.input.button.title", fallback: "Done")
        }
      }
    }
    public enum Done {
      /// Last backup %@
      public static func subtitle(_ p1: Any) -> String {
        return TKLocales.tr("Localizable", "backup.done.subtitle", String(describing: p1), fallback: "Last backup %@")
      }
      /// Manual Backup On
      public static let title = TKLocales.tr("Localizable", "backup.done.title", fallback: "Manual Backup On")
    }
    public enum Information {
      /// Back up your wallet manually by writing down the recovery phrase.
      public static let subtitle = TKLocales.tr("Localizable", "backup.information.subtitle", fallback: "Back up your wallet manually by writing down the recovery phrase.")
      /// Manual
      public static let title = TKLocales.tr("Localizable", "backup.information.title", fallback: "Manual")
    }
    public enum Manually {
      /// Back Up Manually
      public static let button = TKLocales.tr("Localizable", "backup.manually.button", fallback: "Back Up Manually")
    }
    public enum Show {
      /// Write down these words with their numbers and store them in a safe place.
      public static let caption = TKLocales.tr("Localizable", "backup.show.caption", fallback: "Write down these words with their numbers and store them in a safe place.")
      /// Recovery phrase
      public static let title = TKLocales.tr("Localizable", "backup.show.title", fallback: "Recovery phrase")
      public enum Button {
        /// Copy
        public static let title = TKLocales.tr("Localizable", "backup.show.button.title", fallback: "Copy")
      }
    }
    public enum ShowPhrase {
      /// Show Recovery Phrase
      public static let title = TKLocales.tr("Localizable", "backup.show_phrase.title", fallback: "Show Recovery Phrase")
    }
    public enum Warning {
      /// Please read the following carefully before viewing your recovery phrase.
      public static let caption = TKLocales.tr("Localizable", "backup.warning.caption", fallback: "Please read the following carefully before viewing your recovery phrase.")
      /// Attention
      public static let title = TKLocales.tr("Localizable", "backup.warning.title", fallback: "Attention")
      public enum List {
        /// Never enter your recovery phrase any other place than Tonkeeper to access your wallet.
        public static let item1 = TKLocales.tr("Localizable", "backup.warning.list.item1", fallback: "Never enter your recovery phrase any other place than Tonkeeper to access your wallet.")
        /// Tonkeeper Support never asks for a recovery phrase.
        public static let item2 = TKLocales.tr("Localizable", "backup.warning.list.item2", fallback: "Tonkeeper Support never asks for a recovery phrase.")
        /// Everybody with your recovery phrase can access your wallet.
        public static let item3 = TKLocales.tr("Localizable", "backup.warning.list.item3", fallback: "Everybody with your recovery phrase can access your wallet.")
      }
    }
  }
  public enum BalanceHeader {
    /// Address: 
    public static let address = TKLocales.tr("Localizable", "balance_header.address", fallback: "Address: ")
    /// Your address: 
    public static let yourAddress = TKLocales.tr("Localizable", "balance_header.your_address", fallback: "Your address: ")
  }
  public enum BalanceList {
    public enum StakingItem {
      /// Staked
      public static let title = TKLocales.tr("Localizable", "balance_list.staking_item.title", fallback: "Staked")
      public enum Comment {
        /// after the end of the cycle
        public static let afterEndOfCycle = TKLocales.tr("Localizable", "balance_list.staking_item.comment.after_end_of_cycle", fallback: "after the end of the cycle")
        /// %@ TON ready.
        /// Tap to collect.
        public static func ready(_ p1: Any) -> String {
          return TKLocales.tr("Localizable", "balance_list.staking_item.comment.ready", String(describing: p1), fallback: "%@ TON ready.\nTap to collect.")
        }
        /// %@ TON staked
        public static func staked(_ p1: Any) -> String {
          return TKLocales.tr("Localizable", "balance_list.staking_item.comment.staked", String(describing: p1), fallback: "%@ TON staked")
        }
        /// in %@
        public static func timeEstimate(_ p1: Any) -> String {
          return TKLocales.tr("Localizable", "balance_list.staking_item.comment.time_estimate", String(describing: p1), fallback: "in %@")
        }
        /// %@ TON unstaked
        public static func unstaked(_ p1: Any) -> String {
          return TKLocales.tr("Localizable", "balance_list.staking_item.comment.unstaked", String(describing: p1), fallback: "%@ TON unstaked")
        }
      }
    }
  }
  public enum Bluetooth {
    public enum PermissionsAlert {
      /// Please enable Bluetooth permissions in your settings to use this feature
      public static let message = TKLocales.tr("Localizable", "bluetooth.permissions_alert.message", fallback: "Please enable Bluetooth permissions in your settings to use this feature")
      /// Open Settings
      public static let openSettings = TKLocales.tr("Localizable", "bluetooth.permissions_alert.open_settings", fallback: "Open Settings")
      /// Bluetooth Permissions
      public static let title = TKLocales.tr("Localizable", "bluetooth.permissions_alert.title", fallback: "Bluetooth Permissions")
    }
    public enum PoweredOffAlert {
      /// Please turn on Bluetooth to use this feature
      public static let message = TKLocales.tr("Localizable", "bluetooth.powered_off_alert.message", fallback: "Please turn on Bluetooth to use this feature")
      /// Open Settings
      public static let openSettings = TKLocales.tr("Localizable", "bluetooth.powered_off_alert.open_settings", fallback: "Open Settings")
      /// Bluetooth is off
      public static let title = TKLocales.tr("Localizable", "bluetooth.powered_off_alert.title", fallback: "Bluetooth is off")
    }
  }
  public enum Browser {
    public enum ConnectedApps {
      /// Explore apps and services in Tonkeeper browser.
      public static let emptyDescription = TKLocales.tr("Localizable", "browser.connected_apps.empty_description", fallback: "Explore apps and services in Tonkeeper browser.")
      /// Connected apps will be shown here
      public static let emptyTitle = TKLocales.tr("Localizable", "browser.connected_apps.empty_title", fallback: "Connected apps will be shown here")
    }
    public enum List {
      /// All
      public static let all = TKLocales.tr("Localizable", "browser.list.all", fallback: "All")
    }
    public enum Search {
      /// Open link
      public static let openLinkPlaceholder = TKLocales.tr("Localizable", "browser.search.open_link_placeholder", fallback: "Open link")
      /// Enter an address or search the web
      public static let placeholder = TKLocales.tr("Localizable", "browser.search.placeholder", fallback: "Enter an address or search the web")
      /// Browser
      public static let title = TKLocales.tr("Localizable", "browser.search.title", fallback: "Browser")
      public enum DuckgoSearch {
        /// DuckDuckGo Search
        public static let title = TKLocales.tr("Localizable", "browser.search.duckgo_search.title", fallback: "DuckDuckGo Search")
      }
      public enum GoogleSearch {
        /// Google Search
        public static let title = TKLocales.tr("Localizable", "browser.search.google_search.title", fallback: "Google Search")
      }
    }
    public enum SearchField {
      /// Search or enter address
      public static let placeholder = TKLocales.tr("Localizable", "browser.search_field.placeholder", fallback: "Search or enter address")
    }
    public enum Tab {
      /// Connected
      public static let connected = TKLocales.tr("Localizable", "browser.tab.connected", fallback: "Connected")
      /// Explore
      public static let explore = TKLocales.tr("Localizable", "browser.tab.explore", fallback: "Explore")
    }
  }
  public enum BuyListPopup {
    /// You are opening an external app not operated by Tonkeeper.
    public static let youAreOpeningExternalApp = TKLocales.tr("Localizable", "buy_list_popup.you_are_opening_external_app", fallback: "You are opening an external app not operated by Tonkeeper.")
  }
  public enum BuySellList {
    /// Buy
    public static let buy = TKLocales.tr("Localizable", "buy_sell_list.buy", fallback: "Buy")
    /// Sell
    public static let sell = TKLocales.tr("Localizable", "buy_sell_list.sell", fallback: "Sell")
  }
  public enum CameraPermission {
    /// Open Settings
    public static let button = TKLocales.tr("Localizable", "camera_permission.button", fallback: "Open Settings")
    /// Enable access to your camera in order to can scan QR codes
    public static let title = TKLocales.tr("Localizable", "camera_permission.title", fallback: "Enable access to your camera in order to can scan QR codes")
  }
  public enum Chart {
    /// Price
    public static let price = TKLocales.tr("Localizable", "chart.price", fallback: "Price")
  }
  public enum ChooseWallets {
    /// Already added
    public static let alreadyAdded = TKLocales.tr("Localizable", "choose_wallets.alreadyAdded", fallback: "Already added")
    /// Choose wallets you want to add.
    public static let description = TKLocales.tr("Localizable", "choose_wallets.description", fallback: "Choose wallets you want to add.")
    /// Choose Wallets
    public static let title = TKLocales.tr("Localizable", "choose_wallets.title", fallback: "Choose Wallets")
    /// tokens
    public static let tokens = TKLocales.tr("Localizable", "choose_wallets.tokens", fallback: "tokens")
  }
  public enum Collectibles {
    /// Collection hidden
    public static let collectionHidden = TKLocales.tr("Localizable", "collectibles.collection_hidden", fallback: "Collection hidden")
    /// NFT hidden
    public static let nftHidden = TKLocales.tr("Localizable", "collectibles.nft_hidden", fallback: "NFT hidden")
    /// Collectibles
    public static let title = TKLocales.tr("Localizable", "collectibles.title", fallback: "Collectibles")
  }
  public enum ConfirmSend {
    /// Amount
    public static let amount = TKLocales.tr("Localizable", "confirm_send.amount", fallback: "Amount")
    /// Comment
    public static let comment = TKLocales.tr("Localizable", "confirm_send.comment", fallback: "Comment")
    /// Confirm
    public static let confirm = TKLocales.tr("Localizable", "confirm_send.confirm", fallback: "Confirm")
    /// Confirm and send
    public static let confirmButton = TKLocales.tr("Localizable", "confirm_send.confirm_button", fallback: "Confirm and send")
    /// Fee
    public static let fee = TKLocales.tr("Localizable", "confirm_send.fee", fallback: "Fee")
    /// Wallet
    public static let wallet = TKLocales.tr("Localizable", "confirm_send.wallet", fallback: "Wallet")
    public enum Recipient {
      /// Recipient address
      public static let address = TKLocales.tr("Localizable", "confirm_send.recipient.address", fallback: "Recipient address")
      /// Recipient
      public static let title = TKLocales.tr("Localizable", "confirm_send.recipient.title", fallback: "Recipient")
    }
    public enum Risk {
      /// confirm_send.risk.action_button_title = OK
      public static let actionButtonTitleOK = TKLocales.tr("Localizable", "confirm_send.risk.action_button_title = OK", fallback: "confirm_send.risk.action_button_title = OK")
      /// The total value of tokens that will be sent from your wallet. Refunds are not included in the total value.
      public static let captionWithoutNft = TKLocales.tr("Localizable", "confirm_send.risk.caption_without_nft", fallback: "The total value of tokens that will be sent from your wallet. Refunds are not included in the total value.")
      /// The total value of tokens, excluding the cost of NFTs, that will be sent from your wallet. Refunds are not included in the total value.
      public static let nftCaption = TKLocales.tr("Localizable", "confirm_send.risk.nft_caption", fallback: "The total value of tokens, excluding the cost of NFTs, that will be sent from your wallet. Refunds are not included in the total value.")
      /// Total: %@
      public static func total(_ p1: Any) -> String {
        return TKLocales.tr("Localizable", "confirm_send.risk.total", String(describing: p1), fallback: "Total: %@")
      }
      /// Total: %@ + %ld NFT
      public static func totalNft(_ p1: Any, _ p2: Int) -> String {
        return TKLocales.tr("Localizable", "confirm_send.risk.total_nft", String(describing: p1), p2, fallback: "Total: %@ + %ld NFT")
      }
    }
    public enum TokenTransfer {
      /// Confirm action
      public static let title = TKLocales.tr("Localizable", "confirm_send.token_transfer.title", fallback: "Confirm action")
      /// Transfer %@
      public static func transfer(_ p1: Any) -> String {
        return TKLocales.tr("Localizable", "confirm_send.token_transfer.transfer", String(describing: p1), fallback: "Transfer %@")
      }
    }
  }
  public enum ConnectionStatus {
    /// No Internet connection
    public static let noInternet = TKLocales.tr("Localizable", "connection_status.no_internet", fallback: "No Internet connection")
    /// Updated %@
    public static func updatedAt(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "connection_status.updated_at", String(describing: p1), fallback: "Updated %@")
    }
    /// Updating
    public static let updating = TKLocales.tr("Localizable", "connection_status.updating", fallback: "Updating")
  }
  public enum Currency {
    /// Primary currency
    public static let title = TKLocales.tr("Localizable", "currency.title", fallback: "Primary currency")
    public enum Items {
      /// United Arab Emirates Dirham
      public static let aed = TKLocales.tr("Localizable", "currency.items.aed", fallback: "United Arab Emirates Dirham")
      /// Swiss Franc
      public static let chf = TKLocales.tr("Localizable", "currency.items.chf", fallback: "Swiss Franc")
      /// China Yuan
      public static let cny = TKLocales.tr("Localizable", "currency.items.cny", fallback: "China Yuan")
      /// Euro
      public static let eur = TKLocales.tr("Localizable", "currency.items.eur", fallback: "Euro")
      /// Great Britain Pound
      public static let gbp = TKLocales.tr("Localizable", "currency.items.gbp", fallback: "Great Britain Pound")
      /// Indonesian Rupiah
      public static let idr = TKLocales.tr("Localizable", "currency.items.idr", fallback: "Indonesian Rupiah")
      /// Indian Rupee
      public static let inr = TKLocales.tr("Localizable", "currency.items.inr", fallback: "Indian Rupee")
      /// Japanese Yen
      public static let jpy = TKLocales.tr("Localizable", "currency.items.jpy", fallback: "Japanese Yen")
      /// South Korean Won
      public static let krw = TKLocales.tr("Localizable", "currency.items.krw", fallback: "South Korean Won")
      /// Kazakhstani Tenge
      public static let kzt = TKLocales.tr("Localizable", "currency.items.kzt", fallback: "Kazakhstani Tenge")
      /// Russian Ruble
      public static let rub = TKLocales.tr("Localizable", "currency.items.rub", fallback: "Russian Ruble")
      /// Ukrainian hryvnian
      public static let uah = TKLocales.tr("Localizable", "currency.items.uah", fallback: "Ukrainian hryvnian")
      /// United States Dollar
      public static let usd = TKLocales.tr("Localizable", "currency.items.usd", fallback: "United States Dollar")
    }
  }
  public enum CustomizeWallet {
    /// Wallet
    public static let defaultWalletName = TKLocales.tr("Localizable", "customize_wallet.default_wallet_name", fallback: "Wallet")
    /// Wallet name and icon are stored locally on your device.
    public static let description = TKLocales.tr("Localizable", "customize_wallet.description", fallback: "Wallet name and icon are stored locally on your device.")
    /// Wallet Name
    public static let inputPlaceholder = TKLocales.tr("Localizable", "customize_wallet.input_placeholder", fallback: "Wallet Name")
    /// Customize your Wallet
    public static let title = TKLocales.tr("Localizable", "customize_wallet.title", fallback: "Customize your Wallet")
  }
  public enum Dates {
    /// Today
    public static let today = TKLocales.tr("Localizable", "dates.today", fallback: "Today")
    /// Yesterday
    public static let yesterday = TKLocales.tr("Localizable", "dates.yesterday", fallback: "Yesterday")
  }
  public enum DecryptCommentPopup {
    /// Decrypt the comment
    public static let button = TKLocales.tr("Localizable", "decrypt_comment_popup.button", fallback: "Decrypt the comment")
    /// The comment is encrypted by sender and can only be decrypted by you. Please be careful with the content and beware of scams.
    public static let caption = TKLocales.tr("Localizable", "decrypt_comment_popup.caption", fallback: "The comment is encrypted by sender and can only be decrypted by you. Please be careful with the content and beware of scams.")
    /// Encrypted comment
    public static let title = TKLocales.tr("Localizable", "decrypt_comment_popup.title", fallback: "Encrypted comment")
  }
  public enum DeleteWalletWarning {
    /// Delete Wallet Data
    public static let button = TKLocales.tr("Localizable", "delete_wallet_warning.button", fallback: "Delete Wallet Data")
    /// Wallet keys and all personal data will be erased from this device.
    public static let caption = TKLocales.tr("Localizable", "delete_wallet_warning.caption", fallback: "Wallet keys and all personal data will be erased from this device.")
    /// Back up
    public static let tickBackUp = TKLocales.tr("Localizable", "delete_wallet_warning.tick_back_up", fallback: "Back up")
    /// I have a backup copy of the recovery phrase for 
    public static let tickDescription = TKLocales.tr("Localizable", "delete_wallet_warning.tick_description", fallback: "I have a backup copy of the recovery phrase for ")
    /// Delete Wallet Data
    public static let title = TKLocales.tr("Localizable", "delete_wallet_warning.title", fallback: "Delete Wallet Data")
  }
  public enum Errors {
    /// Please use Tonkeeper Desktop for Multi-Wallet Account
    public static let multiaccountError = TKLocales.tr("Localizable", "errors.multiaccount_error", fallback: "Please use Tonkeeper Desktop for Multi-Wallet Account")
    /// Error
    public static let unknown = TKLocales.tr("Localizable", "errors.unknown", fallback: "Error")
  }
  public enum EventDetails {
    /// Burned on %@
    public static func burnedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.burned_on", String(describing: p1), fallback: "Burned on %@")
    }
    /// Called contract on %@
    public static func calledContractOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.called_contract_on", String(describing: p1), fallback: "Called contract on %@")
    }
    /// Comment
    public static let comment = TKLocales.tr("Localizable", "event_details.comment", fallback: "Comment")
    /// Description
    public static let description = TKLocales.tr("Localizable", "event_details.description", fallback: "Description")
    /// Domain Renew
    public static let domainRenew = TKLocales.tr("Localizable", "event_details.domain_renew", fallback: "Domain Renew")
    /// Fee
    public static let fee = TKLocales.tr("Localizable", "event_details.fee", fallback: "Fee")
    /// Operation
    public static let operation = TKLocales.tr("Localizable", "event_details.operation", fallback: "Operation")
    /// Payload
    public static let payload = TKLocales.tr("Localizable", "event_details.payload", fallback: "Payload")
    /// Purchased on %@
    public static func purchasedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.purchased_on", String(describing: p1), fallback: "Purchased on %@")
    }
    /// Received
    public static let received = TKLocales.tr("Localizable", "event_details.received", fallback: "Received")
    /// Received on %@
    public static func receivedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.received_on", String(describing: p1), fallback: "Received on %@")
    }
    /// Recipient
    public static let recipient = TKLocales.tr("Localizable", "event_details.recipient", fallback: "Recipient")
    /// Recipient address
    public static let recipientAddress = TKLocales.tr("Localizable", "event_details.recipient_address", fallback: "Recipient address")
    /// Renewed on %@
    public static func renewedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.renewed_on", String(describing: p1), fallback: "Renewed on %@")
    }
    /// Sender
    public static let sender = TKLocales.tr("Localizable", "event_details.sender", fallback: "Sender")
    /// Sender address
    public static let senderAddress = TKLocales.tr("Localizable", "event_details.sender_address", fallback: "Sender address")
    /// Sent
    public static let sent = TKLocales.tr("Localizable", "event_details.sent", fallback: "Sent")
    /// Sent on %@
    public static func sentOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.sent_on", String(describing: p1), fallback: "Sent on %@")
    }
    /// Staked on %@
    public static func stakedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.staked_on", String(describing: p1), fallback: "Staked on %@")
    }
    /// Operation
    public static let swapped = TKLocales.tr("Localizable", "event_details.swapped", fallback: "Operation")
    /// Swapped on %@
    public static func swappedOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.swapped_on", String(describing: p1), fallback: "Swapped on %@")
    }
    /// Transaction 
    public static let transaction = TKLocales.tr("Localizable", "event_details.transaction", fallback: "Transaction ")
    /// Unknown
    public static let unknown = TKLocales.tr("Localizable", "event_details.unknown", fallback: "Unknown")
    /// Something happened but we don't understand what.
    public static let unknownDescription = TKLocales.tr("Localizable", "event_details.unknown_description", fallback: "Something happened but we don't understand what.")
    /// Unstake amount
    public static let unstakeAmount = TKLocales.tr("Localizable", "event_details.unstake_amount", fallback: "Unstake amount")
    /// Unstake on %@
    public static func unstakeOn(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "event_details.unstake_on", String(describing: p1), fallback: "Unstake on %@")
    }
    /// Unstake Request
    public static let unstakeRequest = TKLocales.tr("Localizable", "event_details.unstake_request", fallback: "Unstake Request")
    /// Walelt initialized
    public static let walletInitialized = TKLocales.tr("Localizable", "event_details.wallet_initialized", fallback: "Walelt initialized")
    public enum Recipient {
      /// Recipient address
      public static let address = TKLocales.tr("Localizable", "event_details.recipient.address", fallback: "Recipient address")
      /// Recipient
      public static let title = TKLocales.tr("Localizable", "event_details.recipient.title", fallback: "Recipient")
    }
    public enum Sender {
      /// Sender address
      public static let address = TKLocales.tr("Localizable", "event_details.sender.address", fallback: "Sender address")
      /// Sender
      public static let title = TKLocales.tr("Localizable", "event_details.sender.title", fallback: "Sender")
    }
  }
  public enum FinishSetup {
    /// Back up the wallet recovery phrase
    public static let backup = TKLocales.tr("Localizable", "finish_setup.backup", fallback: "Back up the wallet recovery phrase")
    /// Biometry unavailable
    public static let biometryUnavailable = TKLocales.tr("Localizable", "finish_setup.biometry_unavailable", fallback: "Biometry unavailable")
    /// Use %@ to approve transactions
    public static func setupBiometry(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "finish_setup.setup_biometry", String(describing: p1), fallback: "Use %@ to approve transactions")
    }
    /// Finish setting up
    public static let title = TKLocales.tr("Localizable", "finish_setup.title", fallback: "Finish setting up")
  }
  public enum History {
    /// History
    public static let title = TKLocales.tr("Localizable", "history.title", fallback: "History")
    public enum Placeholder {
      /// Make your first transaction!
      public static let subtitle = TKLocales.tr("Localizable", "history.placeholder.subtitle", fallback: "Make your first transaction!")
      /// Your history
      /// will be shown here
      public static let title = TKLocales.tr("Localizable", "history.placeholder.title", fallback: "Your history\nwill be shown here")
      public enum Buttons {
        /// Buy Toncoin
        public static let buy = TKLocales.tr("Localizable", "history.placeholder.buttons.buy", fallback: "Buy Toncoin")
        /// Receive
        public static let receive = TKLocales.tr("Localizable", "history.placeholder.buttons.receive", fallback: "Receive")
      }
    }
  }
  public enum HomeScreenConfiguration {
    /// Home Screen
    public static let title = TKLocales.tr("Localizable", "home_screen_configuration.title", fallback: "Home Screen")
    public enum Sections {
      /// All Assets
      public static let allAssets = TKLocales.tr("Localizable", "home_screen_configuration.sections.all_assets", fallback: "All Assets")
      /// Pinned
      public static let pinned = TKLocales.tr("Localizable", "home_screen_configuration.sections.pinned", fallback: "Pinned")
      /// Sorted by Price
      public static let sortedByPrice = TKLocales.tr("Localizable", "home_screen_configuration.sections.sorted_by_price", fallback: "Sorted by Price")
    }
  }
  public enum ImportWallet {
    /// When you created this wallet, you got a 24-word recovery phrase. Enter it to restore access to your wallet.
    public static let description = TKLocales.tr("Localizable", "import_wallet.description", fallback: "When you created this wallet, you got a 24-word recovery phrase. Enter it to restore access to your wallet.")
    /// Enter recovery phrase
    public static let title = TKLocales.tr("Localizable", "import_wallet.title", fallback: "Enter recovery phrase")
  }
  public enum Keystone {
    public enum Scan {
      /// About Keystone
      public static let aboutKeystoneButton = TKLocales.tr("Localizable", "keystone.scan.about_keystone_button", fallback: "About Keystone")
      /// Open Keystone » Connect Software Wallet » Tonkeeper
      public static let subtitle = TKLocales.tr("Localizable", "keystone.scan.subtitle", fallback: "Open Keystone » Connect Software Wallet » Tonkeeper")
    }
  }
  public enum KeystoneSign {
    /// Step 1
    public static let stepOne = TKLocales.tr("Localizable", "keystone_sign.step_one", fallback: "Step 1")
    /// Scan the QR code with Keystone
    public static let stepOneDescription = TKLocales.tr("Localizable", "keystone_sign.step_one_description", fallback: "Scan the QR code with Keystone")
    /// Step 3
    public static let stepThree = TKLocales.tr("Localizable", "keystone_sign.step_three", fallback: "Step 3")
    /// Scan signed transaction QR code from Keystone
    public static let stepThreeDescription = TKLocales.tr("Localizable", "keystone_sign.step_three_description", fallback: "Scan signed transaction QR code from Keystone")
    /// Step 2
    public static let stepTwo = TKLocales.tr("Localizable", "keystone_sign.step_two", fallback: "Step 2")
    /// Confirm your transaction in Keystone
    public static let stepTwoDescription = TKLocales.tr("Localizable", "keystone_sign.step_two_description", fallback: "Confirm your transaction in Keystone")
    /// Transaction
    public static let transaction = TKLocales.tr("Localizable", "keystone_sign.transaction", fallback: "Transaction")
  }
  public enum LedgerConfirm {
    /// Confirm Action
    public static let title = TKLocales.tr("Localizable", "ledger_confirm.title", fallback: "Confirm Action")
    public enum Steps {
      public enum BluetoothConnect {
        /// Connect Ledger to your device via Bluetooth
        public static let description = TKLocales.tr("Localizable", "ledger_confirm.steps.bluetooth_connect.description", fallback: "Connect Ledger to your device via Bluetooth")
      }
      public enum Confirm {
        /// Confirm your transaction on Ledger
        public static let description = TKLocales.tr("Localizable", "ledger_confirm.steps.confirm.description", fallback: "Confirm your transaction on Ledger")
      }
      public enum TonApp {
        /// Unlock it and open TON App
        public static let description = TKLocales.tr("Localizable", "ledger_confirm.steps.ton_app.description", fallback: "Unlock it and open TON App")
      }
    }
  }
  public enum LedgerConnect {
    /// Connect Ledger
    public static let title = TKLocales.tr("Localizable", "ledger_connect.title", fallback: "Connect Ledger")
    public enum Steps {
      public enum BluetoothConnect {
        /// Connect Ledger to your device via Bluetooth
        public static let description = TKLocales.tr("Localizable", "ledger_connect.steps.bluetooth_connect.description", fallback: "Connect Ledger to your device via Bluetooth")
      }
      public enum TonApp {
        /// Unlock it and open TON App
        public static let description = TKLocales.tr("Localizable", "ledger_connect.steps.ton_app.description", fallback: "Unlock it and open TON App")
        /// Install TON App
        public static let link = TKLocales.tr("Localizable", "ledger_connect.steps.ton_app.link", fallback: "Install TON App")
      }
    }
  }
  public enum LedgerVersionUpdate {
    /// This type of transaction is not supported in your current application version.
    public static let caption = TKLocales.tr("Localizable", "ledger_version_update.caption", fallback: "This type of transaction is not supported in your current application version.")
    /// Update TON app in Ledger to the %@ version
    public static func title(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "ledger_version_update.title", String(describing: p1), fallback: "Update TON app in Ledger to the %@ version")
    }
  }
  public enum List {
    /// Hide
    public static let hide = TKLocales.tr("Localizable", "list.hide", fallback: "Hide")
    /// Show all
    public static let showAll = TKLocales.tr("Localizable", "list.show_all", fallback: "Show all")
  }
  public enum NftDetails {
    /// About collection
    public static let aboutCollection = TKLocales.tr("Localizable", "nft_details.about_collection", fallback: "About collection")
    /// Contract address
    public static let contractAddress = TKLocales.tr("Localizable", "nft_details.contract_address", fallback: "Contract address")
    /// Details
    public static let details = TKLocales.tr("Localizable", "nft_details.details", fallback: "Details")
    /// Domain is on sale at the marketplace now. For transfer, you should remove it from sale first.
    public static let domainOnSaleDescription = TKLocales.tr("Localizable", "nft_details.domain_on_sale_description", fallback: "Domain is on sale at the marketplace now. For transfer, you should remove it from sale first.")
    /// Expiration date
    public static let expirationDate = TKLocales.tr("Localizable", "nft_details.expiration_date", fallback: "Expiration date")
    /// Expires in %@ days
    public static func expiresInDays(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "nft_details.expires_in_days", String(describing: p1), fallback: "Expires in %@ days")
    }
    /// Link domain
    public static let linkedDomain = TKLocales.tr("Localizable", "nft_details.linked_domain", fallback: "Link domain")
    /// Linked with %@
    public static func linkedWith(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "nft_details.linked_with", String(describing: p1), fallback: "Linked with %@")
    }
    /// NFT is on sale at the marketplace now. For transfer, you should remove it from sale first.
    public static let nftOnSaleDescription = TKLocales.tr("Localizable", "nft_details.nft_on_sale_description", fallback: "NFT is on sale at the marketplace now. For transfer, you should remove it from sale first.")
    /// Owner
    public static let owner = TKLocales.tr("Localizable", "nft_details.owner", fallback: "Owner")
    /// Properties
    public static let properties = TKLocales.tr("Localizable", "nft_details.properties", fallback: "Properties")
    /// Renew until %@
    public static func renewUntil(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "nft_details.renew_until", String(describing: p1), fallback: "Renew until %@")
    }
    /// Single NFT
    public static let singleNft = TKLocales.tr("Localizable", "nft_details.single_nft", fallback: "Single NFT")
    /// Transfer
    public static let transfer = TKLocales.tr("Localizable", "nft_details.transfer", fallback: "Transfer")
    /// Unverified NFT
    public static let unverifiedNft = TKLocales.tr("Localizable", "nft_details.unverified_nft", fallback: "Unverified NFT")
    /// View in explorer
    public static let viewInExplorer = TKLocales.tr("Localizable", "nft_details.view_in_explorer", fallback: "View in explorer")
  }
  public enum Onboarding {
    /// Create a new wallet or add an existing one
    public static let caption = TKLocales.tr("Localizable", "onboarding.caption", fallback: "Create a new wallet or add an existing one")
    public enum Buttons {
      /// Create New Wallet
      public static let createNew = TKLocales.tr("Localizable", "onboarding.buttons.create_new", fallback: "Create New Wallet")
      /// Import Existing Wallet
      public static let importExisting = TKLocales.tr("Localizable", "onboarding.buttons.import_existing", fallback: "Import Existing Wallet")
    }
  }
  public enum Passcode {
    /// Create passcode
    public static let create = TKLocales.tr("Localizable", "passcode.create", fallback: "Create passcode")
    /// Enter passcode
    public static let enter = TKLocales.tr("Localizable", "passcode.enter", fallback: "Enter passcode")
    /// Log Out
    public static let logout = TKLocales.tr("Localizable", "passcode.logout", fallback: "Log Out")
    /// This will erase keys to all wallets. Make sure you have backed up your recovery phrases.
    public static let logoutConfirmationDescription = TKLocales.tr("Localizable", "passcode.logout_confirmation_description", fallback: "This will erase keys to all wallets. Make sure you have backed up your recovery phrases.")
    /// 🚧 🚨🚨🚨 🚧
    /// Sign Out of All Wallets?
    public static let logoutConfirmationTitle = TKLocales.tr("Localizable", "passcode.logout_confirmation_title", fallback: "🚧 🚨🚨🚨 🚧\nSign Out of All Wallets?")
    /// Re-enter passcode
    public static let reenter = TKLocales.tr("Localizable", "passcode.reenter", fallback: "Re-enter passcode")
  }
  public enum Periods {
    /// D
    public static let day = TKLocales.tr("Localizable", "periods.day", fallback: "D")
    /// 6M
    public static let halfYear = TKLocales.tr("Localizable", "periods.half_year", fallback: "6M")
    /// H
    public static let hour = TKLocales.tr("Localizable", "periods.hour", fallback: "H")
    /// M
    public static let month = TKLocales.tr("Localizable", "periods.month", fallback: "M")
    /// W
    public static let week = TKLocales.tr("Localizable", "periods.week", fallback: "W")
    /// Y
    public static let year = TKLocales.tr("Localizable", "periods.year", fallback: "Y")
  }
  public enum Purchases {
    /// Your collectibles
    /// will be shown here
    public static let emptyPlaceholder = TKLocales.tr("Localizable", "purchases.empty_placeholder", fallback: "Your collectibles\nwill be shown here")
    /// Purchases
    public static let title = TKLocales.tr("Localizable", "purchases.title", fallback: "Purchases")
    /// Unnamed collection
    public static let unnamedCollection = TKLocales.tr("Localizable", "purchases.unnamed_collection", fallback: "Unnamed collection")
    /// Unverified
    public static let unverified = TKLocales.tr("Localizable", "purchases.unverified", fallback: "Unverified")
  }
  public enum Receive {
    /// Send only %@ and tokens in TON network to this address, or you might lose your funds.
    public static func description(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "receive.description", String(describing: p1), fallback: "Send only %@ and tokens in TON network to this address, or you might lose your funds.")
    }
    /// Receive %@
    public static func title(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "receive.title", String(describing: p1), fallback: "Receive %@")
    }
  }
  public enum Scanner {
    /// Scan QR code
    public static let title = TKLocales.tr("Localizable", "scanner.title", fallback: "Scan QR code")
  }
  public enum Security {
    /// Change Passcode
    public static let changePasscode = TKLocales.tr("Localizable", "security.change_passcode", fallback: "Change Passcode")
    /// Lock Screen
    public static let lockScreen = TKLocales.tr("Localizable", "security.lock_screen", fallback: "Lock Screen")
    /// Require passcode to view wallet contents.
    public static let lockScreenDescription = TKLocales.tr("Localizable", "security.lock_screen_description", fallback: "Require passcode to view wallet contents.")
    /// Security
    public static let title = TKLocales.tr("Localizable", "security.title", fallback: "Security")
    /// Biometry unavailable
    public static let unavailableError = TKLocales.tr("Localizable", "security.unavailable_error", fallback: "Biometry unavailable")
    /// Use %@
    public static func use(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "security.use", String(describing: p1), fallback: "Use %@")
    }
    /// You can always unlock your wallet with a passcode.
    public static let useBiometryDescription = TKLocales.tr("Localizable", "security.use_biometry_description", fallback: "You can always unlock your wallet with a passcode.")
  }
  public enum Send {
    /// Remaining
    public static let remaining = TKLocales.tr("Localizable", "send.remaining", fallback: "Remaining")
    /// Send
    public static let title = TKLocales.tr("Localizable", "send.title", fallback: "Send")
    public enum Amount {
      /// Amount
      public static let placeholder = TKLocales.tr("Localizable", "send.amount.placeholder", fallback: "Amount")
    }
    public enum Comment {
      /// Use only ASCII characters: digits, latin alphabet letters and punctuation marks.
      public static let asciiError = TKLocales.tr("Localizable", "send.comment.ascii_error", fallback: "Use only ASCII characters: digits, latin alphabet letters and punctuation marks.")
      /// Will be visible to everyone.
      public static let description = TKLocales.tr("Localizable", "send.comment.description", fallback: "Will be visible to everyone.")
      /// Comment
      public static let placeholder = TKLocales.tr("Localizable", "send.comment.placeholder", fallback: "Comment")
    }
    public enum Recepient {
      /// Address or name
      public static let placeholder = TKLocales.tr("Localizable", "send.recepient.placeholder", fallback: "Address or name")
    }
    public enum RequiredComment {
      /// You must include the note from the exchange for transfer. Without it your funds will be lost.
      public static let description = TKLocales.tr("Localizable", "send.required_comment.description", fallback: "You must include the note from the exchange for transfer. Without it your funds will be lost.")
      /// Required comment
      public static let placeholder = TKLocales.tr("Localizable", "send.required_comment.placeholder", fallback: "Required comment")
    }
  }
  public enum Settings {
    /// Settings
    public static let title = TKLocales.tr("Localizable", "settings.title", fallback: "Settings")
    public enum Items {
      /// Backup
      public static let backup = TKLocales.tr("Localizable", "settings.items.backup", fallback: "Backup")
      /// Contact us
      public static let contactUs = TKLocales.tr("Localizable", "settings.items.contact_us", fallback: "Contact us")
      /// Currency
      public static let currency = TKLocales.tr("Localizable", "settings.items.currency", fallback: "Currency")
      /// Delete Account
      public static let deleteAccount = TKLocales.tr("Localizable", "settings.items.delete_account", fallback: "Delete Account")
      /// Delete account
      public static let deleteAcountAlertTitle = TKLocales.tr("Localizable", "settings.items.delete_acount_alert_title", fallback: "Delete account")
      /// Delete Watch account
      public static let deleteWatchOnly = TKLocales.tr("Localizable", "settings.items.delete_watch_only", fallback: "Delete Watch account")
      /// Delete Watch account
      public static let deleteWatchOnlyAcountAlertTitle = TKLocales.tr("Localizable", "settings.items.delete_watch_only_acount_alert_title", fallback: "Delete Watch account")
      /// FAQ
      public static let faq = TKLocales.tr("Localizable", "settings.items.faq", fallback: "FAQ")
      /// Legal
      public static let legal = TKLocales.tr("Localizable", "settings.items.legal", fallback: "Legal")
      /// Sign out
      public static let logout = TKLocales.tr("Localizable", "settings.items.logout", fallback: "Sign out")
      /// Notifications
      public static let notifications = TKLocales.tr("Localizable", "settings.items.notifications", fallback: "Notifications")
      /// Purchases
      public static let purchases = TKLocales.tr("Localizable", "settings.items.purchases", fallback: "Purchases")
      /// Rate %@
      public static func rate(_ p1: Any) -> String {
        return TKLocales.tr("Localizable", "settings.items.rate", String(describing: p1), fallback: "Rate %@")
      }
      /// Search
      public static let search = TKLocales.tr("Localizable", "settings.items.search", fallback: "Search")
      /// Security
      public static let security = TKLocales.tr("Localizable", "settings.items.security", fallback: "Security")
      /// Edit name and color
      public static let setupWalletDescription = TKLocales.tr("Localizable", "settings.items.setup_wallet_description", fallback: "Edit name and color")
      /// Sign Out 
      public static let signOutAccount = TKLocales.tr("Localizable", "settings.items.sign_out_account", fallback: "Sign Out ")
      /// Support
      public static let support = TKLocales.tr("Localizable", "settings.items.support", fallback: "Support")
      /// Theme
      public static let theme = TKLocales.tr("Localizable", "settings.items.theme", fallback: "Theme")
      /// Tonkeeper news
      public static let tkNews = TKLocales.tr("Localizable", "settings.items.tk_news", fallback: "Tonkeeper news")
      /// Wallet v4R2
      public static let walletV4R2 = TKLocales.tr("Localizable", "settings.items.wallet_v4R2", fallback: "Wallet v4R2")
      /// Wallet W5
      public static let walletW5 = TKLocales.tr("Localizable", "settings.items.wallet_w5", fallback: "Wallet W5")
    }
    public enum Legal {
      /// Legal
      public static let title = TKLocales.tr("Localizable", "settings.legal.title", fallback: "Legal")
      public enum Items {
        /// Montserrat font
        public static let montserratFont = TKLocales.tr("Localizable", "settings.legal.items.montserrat_font", fallback: "Montserrat font")
        /// Privacy policy
        public static let privacyPolicy = TKLocales.tr("Localizable", "settings.legal.items.privacy_policy", fallback: "Privacy policy")
        /// Terms of service
        public static let termsOfService = TKLocales.tr("Localizable", "settings.legal.items.terms_of_service", fallback: "Terms of service")
      }
      public enum Sections {
        /// Licences
        public static let licenses = TKLocales.tr("Localizable", "settings.legal.sections.licenses", fallback: "Licences")
      }
    }
    public enum Logout {
      /// This will erase keys to the wallets. Make sure you have backed up your secret recovery phrases.
      public static let description = TKLocales.tr("Localizable", "settings.logout.description", fallback: "This will erase keys to the wallets. Make sure you have backed up your secret recovery phrases.")
      /// Log out?
      public static let title = TKLocales.tr("Localizable", "settings.logout.title", fallback: "Log out?")
    }
    public enum Notifications {
      /// Notifications
      public static let title = TKLocales.tr("Localizable", "settings.notifications.title", fallback: "Notifications")
      public enum NotificationsItem {
        /// Get notifications when you receive TON, tokens and NFTs. Notifications from connected apps.
        public static let caption = TKLocales.tr("Localizable", "settings.notifications.notifications_item.caption", fallback: "Get notifications when you receive TON, tokens and NFTs. Notifications from connected apps.")
        /// Push notifications
        public static let title = TKLocales.tr("Localizable", "settings.notifications.notifications_item.title", fallback: "Push notifications")
      }
    }
    public enum Purchases {
      /// Purchases
      public static let title = TKLocales.tr("Localizable", "settings.purchases.title", fallback: "Purchases")
      public enum Details {
        public enum Button {
          /// Hide collection from wallet
          public static let hideCollection = TKLocales.tr("Localizable", "settings.purchases.details.button.hide_collection", fallback: "Hide collection from wallet")
          /// Hide token from wallet
          public static let hideToken = TKLocales.tr("Localizable", "settings.purchases.details.button.hide_token", fallback: "Hide token from wallet")
          /// Not Spam
          public static let notSpam = TKLocales.tr("Localizable", "settings.purchases.details.button.not_spam", fallback: "Not Spam")
          /// Show collection in wallet
          public static let showCollection = TKLocales.tr("Localizable", "settings.purchases.details.button.show_collection", fallback: "Show collection in wallet")
          /// Show token in wallet
          public static let showToken = TKLocales.tr("Localizable", "settings.purchases.details.button.show_token", fallback: "Show token in wallet")
        }
        public enum Items {
          /// Collection ID
          public static let collectionId = TKLocales.tr("Localizable", "settings.purchases.details.items.collection_id", fallback: "Collection ID")
          /// Name
          public static let name = TKLocales.tr("Localizable", "settings.purchases.details.items.name", fallback: "Name")
          /// Token ID
          public static let tokenId = TKLocales.tr("Localizable", "settings.purchases.details.items.token_id", fallback: "Token ID")
        }
        public enum Title {
          /// Collection details
          public static let collection = TKLocales.tr("Localizable", "settings.purchases.details.title.collection", fallback: "Collection details")
          /// Token details
          public static let singleToken = TKLocales.tr("Localizable", "settings.purchases.details.title.single_token", fallback: "Token details")
        }
      }
      public enum Sections {
        /// Hidden
        public static let hidden = TKLocales.tr("Localizable", "settings.purchases.sections.hidden", fallback: "Hidden")
        /// Spam
        public static let spam = TKLocales.tr("Localizable", "settings.purchases.sections.spam", fallback: "Spam")
        /// Visible
        public static let visible = TKLocales.tr("Localizable", "settings.purchases.sections.visible", fallback: "Visible")
      }
      public enum Token {
        /// Single token
        public static let singleToken = TKLocales.tr("Localizable", "settings.purchases.token.single_token", fallback: "Single token")
        /// Unnamed collection
        public static let unnamedCollection = TKLocales.tr("Localizable", "settings.purchases.token.unnamed_collection", fallback: "Unnamed collection")
        public enum TokenCount {
          /// tokens
          public static let few = TKLocales.tr("Localizable", "settings.purchases.token.token_count.few", fallback: "tokens")
          /// tokens
          public static let many = TKLocales.tr("Localizable", "settings.purchases.token.token_count.many", fallback: "tokens")
          /// token
          public static let one = TKLocales.tr("Localizable", "settings.purchases.token.token_count.one", fallback: "token")
          /// tokens
          public static let other = TKLocales.tr("Localizable", "settings.purchases.token.token_count.other", fallback: "tokens")
          /// tokens
          public static let zero = TKLocales.tr("Localizable", "settings.purchases.token.token_count.zero", fallback: "tokens")
        }
      }
    }
  }
  public enum SettingsListNotificationsConfigurator {
    /// Notifications from connected apps in your activity
    public static let connectedAppsSectionCaption = TKLocales.tr("Localizable", "settings_list_notifications_configurator.connectedAppsSectionCaption", fallback: "Notifications from connected apps in your activity")
    /// Apps
    public static let connectedAppsTitle = TKLocales.tr("Localizable", "settings_list_notifications_configurator.connectedAppsTitle", fallback: "Apps")
  }
  public enum SettingsListSecurityConfigurator {
    /// Face ID
    public static let faceId = TKLocales.tr("Localizable", "settings_list_security_configurator.face_id", fallback: "Face ID")
    /// Touch ID
    public static let touchId = TKLocales.tr("Localizable", "settings_list_security_configurator.touch_id", fallback: "Touch ID")
  }
  public enum SignOutFull {
    /// This will erase keys to all wallets. Make sure you have backed up your recovery phrases.
    public static let description = TKLocales.tr("Localizable", "sign_out_full.description", fallback: "This will erase keys to all wallets. Make sure you have backed up your recovery phrases.")
    /// 🚧 🚨🚨🚨 🚧
    /// Sign Out of All Wallets?
    public static let title = TKLocales.tr("Localizable", "sign_out_full.title", fallback: "🚧 🚨🚨🚨 🚧\nSign Out of All Wallets?")
  }
  public enum SignOutWarning {
    /// Wallet keys will be erased from this device.
    public static let caption = TKLocales.tr("Localizable", "sign_out_warning.caption", fallback: "Wallet keys will be erased from this device.")
    /// Back up
    public static let tickBackUp = TKLocales.tr("Localizable", "sign_out_warning.tick_back_up", fallback: "Back up")
    /// I have a backup copy of the recovery phrase for 
    public static let tickDescription = TKLocales.tr("Localizable", "sign_out_warning.tick_description", fallback: "I have a backup copy of the recovery phrase for ")
    /// Sign Out
    public static let title = TKLocales.tr("Localizable", "sign_out_warning.title", fallback: "Sign Out")
  }
  public enum Signer {
    public enum Scan {
      /// Open Signer on this device
      public static let openSignerButton = TKLocales.tr("Localizable", "signer.scan.open_signer_button", fallback: "Open Signer on this device")
      /// Open Signer » Select the required key » Scan QR code
      public static let subtitle = TKLocales.tr("Localizable", "signer.scan.subtitle", fallback: "Open Signer » Select the required key » Scan QR code")
    }
  }
  public enum SignerSign {
    /// Step 1
    public static let stepOne = TKLocales.tr("Localizable", "signer_sign.step_one", fallback: "Step 1")
    /// Scan the QR code with Signer
    public static let stepOneDescription = TKLocales.tr("Localizable", "signer_sign.step_one_description", fallback: "Scan the QR code with Signer")
    /// Step 3
    public static let stepThree = TKLocales.tr("Localizable", "signer_sign.step_three", fallback: "Step 3")
    /// Scan signed transaction QR code from Signer
    public static let stepThreeDescription = TKLocales.tr("Localizable", "signer_sign.step_three_description", fallback: "Scan signed transaction QR code from Signer")
    /// Step 2
    public static let stepTwo = TKLocales.tr("Localizable", "signer_sign.step_two", fallback: "Step 2")
    /// Confirm your transaction in Signer
    public static let stepTwoDescription = TKLocales.tr("Localizable", "signer_sign.step_two_description", fallback: "Confirm your transaction in Signer")
    /// Transaction
    public static let transaction = TKLocales.tr("Localizable", "signer_sign.transaction", fallback: "Transaction")
  }
  public enum Staking {
    /// Stake
    public static let title = TKLocales.tr("Localizable", "staking.title", fallback: "Stake")
  }
  public enum StakingBalanceDetails {
    /// after the end of the cycle
    public static let afterEndOfCycle = TKLocales.tr("Localizable", "staking_balance_details.after_end_of_cycle", fallback: "after the end of the cycle")
    /// Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.
    public static let description = TKLocales.tr("Localizable", "staking_balance_details.description", fallback: "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.")
    /// When you stake TON in a Tonstakers pool, you receive a token called tsTON that represents your share in the pool. As the pool accumulates profits, your tsTON represents larger amount of TON.
    public static let jettonButtonDescription = TKLocales.tr("Localizable", "staking_balance_details.jetton_button_description", fallback: "When you stake TON in a Tonstakers pool, you receive a token called tsTON that represents your share in the pool. As the pool accumulates profits, your tsTON represents larger amount of TON.")
    /// Minimal Deposit
    public static let minimalDeposit = TKLocales.tr("Localizable", "staking_balance_details.minimal_deposit", fallback: "Minimal Deposit")
    /// Pending Stake
    public static let pendingStake = TKLocales.tr("Localizable", "staking_balance_details.pending_stake", fallback: "Pending Stake")
    /// Pending Unstake
    public static let pendingUnstake = TKLocales.tr("Localizable", "staking_balance_details.pending_unstake", fallback: "Pending Unstake")
    /// Stake
    public static let stake = TKLocales.tr("Localizable", "staking_balance_details.stake", fallback: "Stake")
    /// Tap to collect
    public static let tapToCollect = TKLocales.tr("Localizable", "staking_balance_details.tap_to_collect", fallback: "Tap to collect")
    /// Unstake
    public static let unstake = TKLocales.tr("Localizable", "staking_balance_details.unstake", fallback: "Unstake")
    /// Unstake ready
    public static let unstakeReady = TKLocales.tr("Localizable", "staking_balance_details.unstake_ready", fallback: "Unstake ready")
  }
  public enum StakingDepositInput {
    /// Continue
    public static let continueTitle = TKLocales.tr("Localizable", "staking_deposit_input.continue_title", fallback: "Continue")
    /// Liquid Staking
    public static let liquidStaking = TKLocales.tr("Localizable", "staking_deposit_input.liquid_staking", fallback: "Liquid Staking")
    /// Options
    public static let options = TKLocales.tr("Localizable", "staking_deposit_input.options", fallback: "Options")
    /// Other
    public static let other = TKLocales.tr("Localizable", "staking_deposit_input.other", fallback: "Other")
  }
  public enum StakingDepositPoolPicker {
    /// APY
    public static let apy = TKLocales.tr("Localizable", "staking_deposit_pool_picker.apy", fallback: "APY")
    /// Liquid Staking
    public static let liquidStaking = TKLocales.tr("Localizable", "staking_deposit_pool_picker.liquid_staking", fallback: "Liquid Staking")
    /// MAX APY
    public static let maxApy = TKLocales.tr("Localizable", "staking_deposit_pool_picker.max_apy", fallback: "MAX APY")
    /// Options
    public static let options = TKLocales.tr("Localizable", "staking_deposit_pool_picker.options", fallback: "Options")
    /// Other
    public static let other = TKLocales.tr("Localizable", "staking_deposit_pool_picker.other", fallback: "Other")
  }
  public enum StakingList {
    /// APY
    public static let apy = TKLocales.tr("Localizable", "staking_list.apy", fallback: "APY")
    /// MAX APY
    public static let maxApy = TKLocales.tr("Localizable", "staking_list.max_apy", fallback: "MAX APY")
    /// Minimal Deposit
    public static let minimalDeposit = TKLocales.tr("Localizable", "staking_list.minimal_deposit", fallback: "Minimal Deposit")
    /// Minimum deposit %@
    public static func minimumDepositDescription(_ p1: Any) -> String {
      return TKLocales.tr("Localizable", "staking_list.minimum_deposit_description", String(describing: p1), fallback: "Minimum deposit %@")
    }
  }
  public enum StakingPoolDetails {
    /// APY
    public static let apy = TKLocales.tr("Localizable", "staking_pool_details.apy", fallback: "APY")
    /// Choose
    public static let choose = TKLocales.tr("Localizable", "staking_pool_details.choose", fallback: "Choose")
    /// Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.
    public static let description = TKLocales.tr("Localizable", "staking_pool_details.description", fallback: "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.")
    /// MAX APY
    public static let maxApy = TKLocales.tr("Localizable", "staking_pool_details.max_apy", fallback: "MAX APY")
    /// Minimal Deposit
    public static let minimalDeposit = TKLocales.tr("Localizable", "staking_pool_details.minimal_deposit", fallback: "Minimal Deposit")
  }
  public enum State {
    /// Failed
    public static let failed = TKLocales.tr("Localizable", "state.failed", fallback: "Failed")
  }
  public enum Tabs {
    /// Browser
    public static let browser = TKLocales.tr("Localizable", "tabs.browser", fallback: "Browser")
    /// Collectibles
    public static let collectibles = TKLocales.tr("Localizable", "tabs.collectibles", fallback: "Collectibles")
    /// History
    public static let history = TKLocales.tr("Localizable", "tabs.history", fallback: "History")
    /// Purchases
    public static let purchases = TKLocales.tr("Localizable", "tabs.purchases", fallback: "Purchases")
    /// Wallet
    public static let wallet = TKLocales.tr("Localizable", "tabs.wallet", fallback: "Wallet")
  }
  public enum Theme {
    /// Theme
    public static let title = TKLocales.tr("Localizable", "theme.title", fallback: "Theme")
    public enum Options {
      /// Blue
      public static let blue = TKLocales.tr("Localizable", "theme.options.blue", fallback: "Blue")
      /// Dark
      public static let dark = TKLocales.tr("Localizable", "theme.options.dark", fallback: "Dark")
      /// System
      public static let system = TKLocales.tr("Localizable", "theme.options.system", fallback: "System")
    }
  }
  public enum Tick {
    /// Do not show again
    public static let doNotShowAgain = TKLocales.tr("Localizable", "tick.do_not_show_again", fallback: "Do not show again")
  }
  public enum Toast {
    /// Copied
    public static let copied = TKLocales.tr("Localizable", "toast.copied", fallback: "Copied")
    /// Failed
    public static let failed = TKLocales.tr("Localizable", "toast.failed", fallback: "Failed")
    /// Expired link
    public static let linkExpired = TKLocales.tr("Localizable", "toast.link_expired", fallback: "Expired link")
    /// Loading
    public static let loading = TKLocales.tr("Localizable", "toast.loading", fallback: "Loading")
    /// Service unavailable
    public static let serviceUnavailable = TKLocales.tr("Localizable", "toast.service_unavailable", fallback: "Service unavailable")
  }
  public enum Token {
    /// Unverified token
    public static let unverified = TKLocales.tr("Localizable", "token.unverified", fallback: "Unverified token")
  }
  public enum TonConnect {
    /// Connect wallet
    public static let connectWallet = TKLocales.tr("Localizable", "ton_connect.connect_wallet", fallback: "Connect wallet")
    /// Open Browser and Connect
    public static let openBrowserAndConnect = TKLocales.tr("Localizable", "ton_connect.open_browser_and_connect", fallback: "Open Browser and Connect")
    /// Be sure to check the service address before connecting the wallet.
    public static let sureCheckServiceAddress = TKLocales.tr("Localizable", "ton_connect.sure_check_service_address", fallback: "Be sure to check the service address before connecting the wallet.")
    /// Be sure to check the service address before connecting · Connect without additional check in Browser
    public static let sureCheckServiceAddressConnectWithoutChecking = TKLocales.tr("Localizable", "ton_connect.sure_check_service_address_connect_without_checking", fallback: "Be sure to check the service address before connecting · Connect without additional check in Browser")
  }
  public enum TonConnectMapper {
    /// Allow Notifications
    public static let allowNotifications = TKLocales.tr("Localizable", "ton_connect_mapper.allow_notifications", fallback: "Allow Notifications")
    /// Connect to 
    public static let connectTo = TKLocales.tr("Localizable", "ton_connect_mapper.connect_to", fallback: "Connect to ")
    /// %@ is requesting access to your wallet address%@
    public static func requestingCapture(_ p1: Any, _ p2: Any) -> String {
      return TKLocales.tr("Localizable", "ton_connect_mapper.requesting_capture", String(describing: p1), String(describing: p2), fallback: "%@ is requesting access to your wallet address%@")
    }
  }
  public enum TransactionConfirmation {
    /// Amount
    public static let amount = TKLocales.tr("Localizable", "transaction_confirmation.amount", fallback: "Amount")
    /// APY
    public static let apy = TKLocales.tr("Localizable", "transaction_confirmation.apy", fallback: "APY")
    /// Confirm action
    public static let confirmAction = TKLocales.tr("Localizable", "transaction_confirmation.confirm_action", fallback: "Confirm action")
    /// Deposit
    public static let deposit = TKLocales.tr("Localizable", "transaction_confirmation.deposit", fallback: "Deposit")
    /// Fee
    public static let fee = TKLocales.tr("Localizable", "transaction_confirmation.fee", fallback: "Fee")
    /// Recipient
    public static let recipient = TKLocales.tr("Localizable", "transaction_confirmation.recipient", fallback: "Recipient")
    /// Unstake
    public static let unstake = TKLocales.tr("Localizable", "transaction_confirmation.unstake", fallback: "Unstake")
    /// Unstake amount
    public static let unstakeAmount = TKLocales.tr("Localizable", "transaction_confirmation.unstake_amount", fallback: "Unstake amount")
    /// Wallet
    public static let wallet = TKLocales.tr("Localizable", "transaction_confirmation.wallet", fallback: "Wallet")
    public enum Buttons {
      /// Confirm and Collect
      public static let confirmAndCollect = TKLocales.tr("Localizable", "transaction_confirmation.buttons.confirm_and_collect", fallback: "Confirm and Collect")
      /// Confirm and Stake
      public static let confirmAndStake = TKLocales.tr("Localizable", "transaction_confirmation.buttons.confirm_and_stake", fallback: "Confirm and Stake")
      /// Confirm and Unstake
      public static let confirmAndUnstake = TKLocales.tr("Localizable", "transaction_confirmation.buttons.confirm_and_unstake", fallback: "Confirm and Unstake")
    }
  }
  public enum UglyBuyList {
    /// Buy
    public static let buy = TKLocales.tr("Localizable", "ugly_buy_list.buy", fallback: "Buy")
  }
  public enum Unstaking {
    /// Unstake
    public static let title = TKLocales.tr("Localizable", "unstaking.title", fallback: "Unstake")
  }
  public enum W5Stories {
    public enum Gasless {
      /// Send USDT without having TON – transaction fees will be covered by a few cents of USDT automatically.
      public static let subtitle = TKLocales.tr("Localizable", "w5_stories.gasless.subtitle", fallback: "Send USDT without having TON – transaction fees will be covered by a few cents of USDT automatically.")
      /// Gasless USDT Transfers
      public static let title = TKLocales.tr("Localizable", "w5_stories.gasless.title", fallback: "Gasless USDT Transfers")
    }
    public enum Messages {
      /// W5 increases the number of simultaneous operations from 4 to 255, which can save on fee costs.
      public static let subtitle = TKLocales.tr("Localizable", "w5_stories.messages.subtitle", fallback: "W5 increases the number of simultaneous operations from 4 to 255, which can save on fee costs.")
      /// Up to 255 Operations in One Transaction
      public static let title = TKLocales.tr("Localizable", "w5_stories.messages.title", fallback: "Up to 255 Operations in One Transaction")
    }
    public enum Phrase {
      /// Add W5 Wallet
      public static let button = TKLocales.tr("Localizable", "w5_stories.phrase.button", fallback: "Add W5 Wallet")
      /// Old accounts and W5 use the same recovery phrase – when restoring accounts on a new device, both old and new will appear automatically.
      public static let subtitle = TKLocales.tr("Localizable", "w5_stories.phrase.subtitle", fallback: "Old accounts and W5 use the same recovery phrase – when restoring accounts on a new device, both old and new will appear automatically.")
      /// Recovery Phrase Does Not Change
      public static let title = TKLocales.tr("Localizable", "w5_stories.phrase.title", fallback: "Recovery Phrase Does Not Change")
    }
  }
  public enum WalletBalanceList {
    /// Join Tonkeeper channel
    public static let joinChannel = TKLocales.tr("Localizable", "wallet_balance_list.join_channel", fallback: "Join Tonkeeper channel")
    /// Enable transaction notifications
    public static let transactionNotifications = TKLocales.tr("Localizable", "wallet_balance_list.transaction_notifications", fallback: "Enable transaction notifications")
    public enum ManageButton {
      /// Manage
      public static let title = TKLocales.tr("Localizable", "wallet_balance_list.manage_button.title", fallback: "Manage")
    }
  }
  public enum WalletButtons {
    /// Buy TON
    public static let buy = TKLocales.tr("Localizable", "wallet_buttons.buy", fallback: "Buy TON")
    /// Receive
    public static let receive = TKLocales.tr("Localizable", "wallet_buttons.receive", fallback: "Receive")
    /// Scan
    public static let scan = TKLocales.tr("Localizable", "wallet_buttons.scan", fallback: "Scan")
    /// Send
    public static let send = TKLocales.tr("Localizable", "wallet_buttons.send", fallback: "Send")
    /// Stake
    public static let stake = TKLocales.tr("Localizable", "wallet_buttons.stake", fallback: "Stake")
    /// Swap
    public static let swap = TKLocales.tr("Localizable", "wallet_buttons.swap", fallback: "Swap")
  }
  public enum WalletTags {
    /// Watch only
    public static let watchOnly = TKLocales.tr("Localizable", "wallet_tags.watch_only", fallback: "Watch only")
  }
  public enum WalletsList {
    /// Add Wallet
    public static let addWallet = TKLocales.tr("Localizable", "wallets_list.add_wallet", fallback: "Add Wallet")
    /// Wallets list
    public static let title = TKLocales.tr("Localizable", "wallets_list.title", fallback: "Wallets list")
  }
  public enum WatchAccount {
    /// Monitor wallet activity without recovery phrase. You will be notified of any transactions from this wallet.
    public static let description = TKLocales.tr("Localizable", "watch_account.description", fallback: "Monitor wallet activity without recovery phrase. You will be notified of any transactions from this wallet.")
    /// Address or name
    public static let placeholder = TKLocales.tr("Localizable", "watch_account.placeholder", fallback: "Address or name")
    /// Watch Account
    public static let title = TKLocales.tr("Localizable", "watch_account.title", fallback: "Watch Account")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension TKLocales {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type

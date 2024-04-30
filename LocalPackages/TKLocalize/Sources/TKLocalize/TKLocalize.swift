public enum TKLocales {
  public enum Actions {
    public static var copied: String {
        localize("actions.copied")
    }
    public static var delete: String {
        localize("actions.delete")
    }
    public static var cancel: String {
        localize("actions.cancel")
    }
    public static var save: String {
        localize("actions.save")
    }
    public static var paste: String {
        localize("actions.paste")
    }
    public static var continue_action: String {
        localize("actions.continue_action")
    }
  }
  public enum Tabs {
    public static var wallet: String {
        localize("tabs.wallet")
    }
    public static var history: String {
        localize("tabs.history")
    }
    public static var purchases: String {
        localize("tabs.purchases")
    }
  }
  public enum Purchases {
    public static var title: String {
        localize("purchases.title")
    }
  }
  public enum History {
    public static var title: String {
        localize("history.title")
    }
  }
  public enum EventDetails {
    public static var received: String {
        localize("event_details.received")
    }
    public static var sent: String {
        localize("event_details.sent")
    }
    public enum Recipient {
      public static var title: String {
          localize("event_details.recipient.title")
      }
      public static var address: String {
          localize("event_details.recipient.address")
      }
    }
    public enum Sender {
      public static var title: String {
          localize("event_details.sender.title")
      }
      public static var address: String {
          localize("event_details.sender.address")
      }
    }
    public static var fee: String {
        localize("event_details.fee")
    }
    public static var comment: String {
        localize("event_details.comment")
    }
  }
  public enum Settings {
    public static var title: String {
        localize("settings.title")
    }
    public enum Items {
      public static var security: String {
          localize("settings.items.security")
      }
      public static var backup: String {
          localize("settings.items.backup")
      }
      public static var currency: String {
          localize("settings.items.currency")
      }
      public static var theme: String {
          localize("settings.items.theme")
      }
      public static var logout: String {
          localize("settings.items.logout")
      }
      public static var support: String {
          localize("settings.items.support")
      }
      public static var tk_news: String {
          localize("settings.items.tk_news")
      }
      public static var contact_us: String {
          localize("settings.items.contact_us")
      }
      public static var rate: String {
          localize("settings.items.rate")
      }
      public static var legal: String {
          localize("settings.items.legal")
      }
      public static var delete_account: String {
          localize("settings.items.delete_account")
      }
      public static var setup_wallet_description: String {
          localize("settings.items.setup_wallet_description")
      }
    }
  }
  public enum Theme {
    public static var title: String {
        localize("theme.title")
    }
    public enum Options {
      public static var system: String {
          localize("theme.options.system")
      }
      public static var dark: String {
          localize("theme.options.dark")
      }
      public static var blue: String {
          localize("theme.options.blue")
      }
    }
  }
  public enum Currency {
    public static var title: String {
        localize("currency.title")
    }
  }
  public enum Backup {
    public static var title: String {
        localize("backup.title")
    }
    public enum Information {
      public static var title: String {
          localize("backup.information.title")
      }
      public static var subtitle: String {
          localize("backup.information.subtitle")
      }
    }
    public enum Manually {
      public static var button: String {
          localize("backup.manually.button")
      }
    }
    public enum ShowPhrase {
      public static var title: String {
          localize("backup.show_phrase.title")
      }
    }
  }
  public enum Security {
    public static var title: String {
        localize("security.title")
    }
    public static var use: String {
        localize("security.use")
    }
    public static var change_passcode: String {
        localize("security.change_passcode")
    }
    public static var unavailable_error: String {
        localize("security.unavailable_error")
    }
    public static var use_biometry_description: String {
        localize("security.use_biometry_description")
    }
  }
  public enum WalletButtons {
    public static var send: String {
        localize("wallet_buttons.send")
    }
    public static var receive: String {
        localize("wallet_buttons.receive")
    }
    public static var scan: String {
        localize("wallet_buttons.scan")
    }
    public static var buy: String {
        localize("wallet_buttons.buy")
    }
    public static var swap: String {
        localize("wallet_buttons.swap")
    }
    public static var stake: String {
        localize("wallet_buttons.stake")
    }
  }
  public enum Send {
    public static var title: String {
        localize("send.title")
    }
    public enum Recepient {
      public static var placeholder: String {
          localize("send.recepient.placeholder")
      }
    }
    public enum Amount {
      public static var placeholder: String {
          localize("send.amount.placeholder")
      }
    }
    public enum Comment {
      public static var placeholder: String {
          localize("send.comment.placeholder")
      }
      public static var description: String {
          localize("send.comment.description")
      }
    }
    public enum RequiredComment {
      public static var placeholder: String {
          localize("send.required_comment.placeholder")
      }
      public static var description: String {
          localize("send.required_comment.description")
      }
    }
  }
  public enum ConfirmSend {
    public enum TokenTransfer {
      public static var title: String {
          localize("confirm_send.token_transfer.title")
      }
    }
    public static var fee: String {
        localize("confirm_send.fee")
    }
    public static var wallet: String {
        localize("confirm_send.wallet")
    }
    public static var amount: String {
        localize("confirm_send.amount")
    }
    public static var comment: String {
        localize("confirm_send.comment")
    }
    public enum Recipient {
      public static var title: String {
          localize("confirm_send.recipient.title")
      }
      public static var address: String {
          localize("confirm_send.recipient.address")
      }
    }
    public static var confirm_button: String {
        localize("confirm_send.confirm_button")
    }
  }
  public enum CustomizeWallet {
    public static var title: String {
        localize("customize_wallet.title")
    }
    public static var description: String {
        localize("customize_wallet.description")
    }
    public static var input_placeholder: String {
        localize("customize_wallet.input_placeholder")
    }
    public static var default_wallet_name: String {
        localize("customize_wallet.default_wallet_name")
    }
  }
  public enum ConnectionStatus {
    public static var updating: String {
        localize("connection_status.updating")
    }
    public static var no_internet: String {
        localize("connection_status.no_internet")
    }
  }
}
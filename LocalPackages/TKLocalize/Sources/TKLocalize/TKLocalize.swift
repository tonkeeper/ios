public enum TKLocales {
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
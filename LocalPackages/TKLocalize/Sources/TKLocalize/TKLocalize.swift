import Foundation

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
    }
    
    public enum ConnectionStatus {
        public static var updating: String {
            localize("connection_status.updating")
        }
        public static var noInternet: String {
            localize("connection_status.no_internet")
        }
    }
}

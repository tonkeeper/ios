import WebKit

public struct TKWebDataStore {

  private let wallet: Wallet

  public init(wallet: Wallet) {
    self.wallet = wallet
  }

  public func dataStore() -> WKWebsiteDataStore {
    guard let uuid = UUID(uuidString: wallet.id) else {
      return .default()
    }
    if #available(iOS 17.0, *) {
      return WKWebsiteDataStore(forIdentifier: uuid)
    } else {
      return .default()
    }
  }

  public func removeData(host: String) {
    let types = WKWebsiteDataStore.allWebsiteDataTypes()
    dataStore().fetchDataRecords(ofTypes: types) { records in
      Task {
        let filteredRecords = records.filter { $0.displayName.contains(host) }
        await dataStore().removeData(
          ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
          for: filteredRecords
        )
      }
    }
  }

  public func clearData() {
    let types = WKWebsiteDataStore.allWebsiteDataTypes()
    Task {
      await dataStore().removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0))
    }
  }
}


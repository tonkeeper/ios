import Foundation
import TonSwift

public final class LoadersAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  
  init(servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly) {
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
  }
  
  private weak var _walletBalanceLoader: WalletBalanceLoader?
  var walletBalanceLoader: WalletBalanceLoader {
    if let _walletBalanceLoader {
      return _walletBalanceLoader
    }
    let loader = WalletBalanceLoader(
      walletBalanceStore: storesAssembly.walletBalanceStore,
      balanceService: servicesAssembly.balanceService()
    )
    _walletBalanceLoader = loader
    return loader
  }
  
  private weak var _tonRatesLoader: TonRatesLoader?
  var tonRatesLoader: TonRatesLoader {
    if let _tonRatesLoader {
      return _tonRatesLoader
    }
    let loader = TonRatesLoader(
      tonRatesStore: storesAssembly.tonRatesStore,
      ratesService: servicesAssembly.ratesService()
    )
    _tonRatesLoader = loader
    return loader
  }
  
  private weak var _nftsLoader: NftsLoader?
  var nftsLoader: NftsLoader {
    if let _nftsLoader {
      return _nftsLoader
    }
    let loader = NftsLoader(
      nftsStore: storesAssembly.nftsStore,
      nftsService: servicesAssembly.accountNftService()
    )
    _nftsLoader = loader
    return loader
  }
  
  var chartLoader: ChartV2Loader {
    ChartV2Loader(chartService: servicesAssembly.chartService())
  }
}

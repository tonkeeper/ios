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
  
  private weak var _tonRatesLoaderV2: TonRatesLoaderV2?
  var tonRatesLoaderV2: TonRatesLoaderV2 {
    if let _tonRatesLoaderV2 {
      return _tonRatesLoaderV2
    }
    let loader = TonRatesLoaderV2(
      tonRatesStore: storesAssembly.tonRatesStoreV2,
      ratesService: servicesAssembly.ratesService(),
      currencyStore: storesAssembly.currencyStoreV2
    )
    _tonRatesLoaderV2 = loader
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

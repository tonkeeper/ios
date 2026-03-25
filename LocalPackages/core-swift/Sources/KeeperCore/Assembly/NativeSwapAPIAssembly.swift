import Foundation

final class NativeSwapAPIAssembly {
    private var _nativeSwapAPI: NativeSwapAPI?

    let configurationAssembly: ConfigurationAssembly

    init(configurationAssembly: ConfigurationAssembly) {
        self.configurationAssembly = configurationAssembly
    }

    func nativeSwapAPI() -> NativeSwapAPI {
        if let nativeSwapAPI = _nativeSwapAPI {
            return nativeSwapAPI
        }
        let nativeSwapAPI = NativeSwapAPIImplementation(
            urlSession: .shared,
            configuration: configurationAssembly.configuration
        )
        _nativeSwapAPI = nativeSwapAPI
        return nativeSwapAPI
    }
}

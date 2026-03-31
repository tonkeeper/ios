import Foundation

public protocol NativeSwapService {
    func fetchAssets(network: Network) async throws -> [SwapAsset]
    func subscribeToSwapConfirmation(data: SwapConfirmationData, network: Network) -> AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>>
}

final class NativeSwapServiceImplementation: NativeSwapService {
    private let nativeSwapAPI: NativeSwapAPI

    init(nativeSwapAPI: NativeSwapAPI) {
        self.nativeSwapAPI = nativeSwapAPI
    }

    func fetchAssets(network: Network) async throws -> [SwapAsset] {
        try await nativeSwapAPI.fetchAssets(network: network)
    }

    func subscribeToSwapConfirmation(data: SwapConfirmationData, network: Network) -> AsyncStream<Result<SwapConfirmation, NativeSwapAPIError>> {
        nativeSwapAPI.subscribeToSwapConfirmation(data: data, network: network)
    }
}

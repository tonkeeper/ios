import SwapAPI

public struct MultichainSwapDefaultPair: Sendable, Hashable {
    public var sourceAsset: MultichainSwapAsset?
    public var destinationAsset: MultichainSwapAsset?

    public init(sourceAsset: MultichainSwapAsset?, destinationAsset: MultichainSwapAsset?) {
        self.sourceAsset = sourceAsset
        self.destinationAsset = destinationAsset
    }
}

extension MultichainSwapDefaultPair {
    init(api: SwapAPI.Components.Schemas.CrossSwapDefaultPair) {
        self.init(
            sourceAsset: MultichainSwapAsset(api: api.source_asset),
            destinationAsset: MultichainSwapAsset(api: api.destination_asset)
        )
    }
}

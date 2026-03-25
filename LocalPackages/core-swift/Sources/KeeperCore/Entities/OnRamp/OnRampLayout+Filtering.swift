public extension OnRampLayout {
    func filteredByCashOrCryptoAvailability(isAvailable: Bool) -> OnRampLayout {
        guard !isAvailable else {
            return self
        }

        return OnRampLayout(assets: [])
    }

    func filteredByTRC20Availability(isAvailable: Bool) -> OnRampLayout {
        guard !isAvailable else {
            return self
        }

        return OnRampLayout(
            assets: assets.compactMap { asset in
                guard !asset.isTronNetwork else {
                    return nil
                }

                return asset.filteringOutTronNetworks()
            }
        )
    }
}

private extension OnRampLayoutToken {
    func filteringOutTronNetworks() -> OnRampLayoutToken {
        OnRampLayoutToken(
            symbol: symbol,
            assetId: assetId,
            address: address,
            network: network,
            networkName: networkName,
            networkImage: networkImage,
            image: image,
            decimals: decimals,
            stablecoin: stablecoin,
            cashMethods: cashMethods,
            cryptoMethods: cryptoMethods.filter { !$0.isTronNetwork }
        )
    }
}

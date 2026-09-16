import ReownWalletKit

extension WalletConnectDapp {
    init(metadata: AppMetadata) {
        self.init(
            name: metadata.name,
            url: metadata.url,
            description: metadata.description,
            iconURL: metadata.icons.first,
            redirect: metadata.redirect.map {
                WalletConnectDappRedirect(
                    native: $0.native,
                    universal: $0.universal
                )
            }
        )
    }
}

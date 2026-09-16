import Foundation

public struct WalletConnectDappRedirect: Codable, Sendable, Equatable {
    public var native: String?
    public var universal: String?

    public init(native: String?, universal: String?) {
        self.native = native
        self.universal = universal
    }
}

public struct WalletConnectDapp: Codable, Sendable, Equatable {
    public var name: String
    public var url: String
    public var description: String
    public var iconURL: String?
    public var redirect: WalletConnectDappRedirect?

    public init(
        name: String,
        url: String,
        description: String,
        iconURL: String?,
        redirect: WalletConnectDappRedirect? = nil
    ) {
        self.name = name
        self.url = url
        self.description = description
        self.iconURL = iconURL
        self.redirect = redirect
    }
}

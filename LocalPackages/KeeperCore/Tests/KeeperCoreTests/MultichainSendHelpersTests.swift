import Foundation
@testable import KeeperCore
import Testing

struct MultichainAssetNativeTests {
    @Test
    func nativeCoinsAreNative() {
        #expect(details(assetId: "ton/mainnet/coin").isNative)
        #expect(details(assetId: "btc/mainnet/coin").isNative)
        #expect(details(assetId: "eth/mainnet/coin").isNative)
    }

    @Test
    func tokensAreNotNative() {
        #expect(!details(assetId: "ton/mainnet/jetton/EQCcBtmfDHu6636TXmba9yImH").isNative)
        #expect(!details(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t").isNative)
        #expect(!details(assetId: "eth/mainnet/erc20/0x71C7656EC7ab88b098defB751B7401B5f6d8976F").isNative)
    }

    private func details(assetId: String) -> MultichainAssetDetails {
        MultichainAssetDetails(assetId: assetId, name: "Name", symbol: "SYM", decimals: 9, image: "")
    }
}

struct StringShortenedMiddleTests {
    @Test
    func truncatesLongAddress() {
        #expect(
            "0x71C7656EC7ab88b098defB751B7401B5f6d8976F".shortenedMiddle() == "0x71C765...d8976F"
        )
        #expect(
            "UQAvlWFDxGF2lXm67y4yzC17wYKD9A0guwPkMs1gOsM__NOT".shortenedMiddle() == "UQAvlW...M__NOT"
        )
    }

    @Test
    func doesNotCountHexPrefixInLimit() {
        #expect("0x71C7656EC7ab88b098defB751B7401B5f6d8976F".shortenedMiddle(prefix: 4, suffix: 4) == "0x71C7...976F")
        #expect("0X71C7656EC7ab88b098defB751B7401B5f6d8976F".shortenedMiddle(prefix: 4, suffix: 4) == "0X71C7...976F")
    }

    @Test
    func keepsShortStringUnchanged() {
        #expect("0x71976F".shortenedMiddle() == "0x71976F")
        #expect("short".shortenedMiddle() == "short")
    }

    @Test
    func customPrefixSuffix() {
        #expect("abcdefghij".shortenedMiddle(prefix: 2, suffix: 2) == "ab...ij")
    }
}

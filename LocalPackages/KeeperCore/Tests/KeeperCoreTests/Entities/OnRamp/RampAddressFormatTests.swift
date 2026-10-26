@testable import KeeperCore
import XCTest

final class RampAddressFormatTests: XCTestCase {
    private let evmAddress = "0x3dA56A7b93ba93ECe9E9a9DE4C76079010315E59"
    private let tonAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private let tronAddress = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
    private let solanaAddress = "mvines9iiHiQTysrwkJjGf2gb9Ex9jXJX8ns3qwf2kN"

    func testFormatFollowsAssetIdChain() {
        let cases: [(assetId: String, format: RampAddressFormat?)] = [
            ("ton/mainnet/coin", .ton),
            ("ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe", .ton),
            ("tron/mainnet/trc20/tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t", .tron),
            ("eth/mainnet/coin", .evm),
            ("eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7", .evm),
            ("bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955", .evm),
            ("arb/mainnet/erc20/0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", .evm),
            ("op/mainnet/erc20/0x0b2c639c533813f4aa9d7837caf62653d097ff85", .evm),
            ("polygon/mainnet/erc20/0xc2132d05d31c914a87c6611c10748aeb04b58e8f", .evm),
            ("base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", .evm),
            ("avax/mainnet/erc20/0x9702230a8ea53601f5cd2dc00fdbc13d4df4a8c7", .evm),
            ("sol/mainnet/coin", .solana),
            ("sol/mainnet/spl/es9vmfrzacermjfrf4h2fyd4kconky11mcce8benwnyb", .solana),
            ("near/mainnet/nep141/usdt.tether-token.near", .near),
            ("btc/mainnet/coin", nil),
            ("xrp/mainnet/coin", nil),
        ]

        for (assetId, format) in cases {
            XCTAssertEqual(RampAddressFormat(assetId: assetId), format, assetId)
        }
    }

    func testEvmRecipientIsReadFromAddressAndTransferLinks() {
        let arbitrumUSDT = "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
        let payloads = [
            evmAddress,
            " \(evmAddress)\n",
            "ethereum:\(evmAddress)",
            "ethereum:\(evmAddress)@10",
            "ethereum:pay-\(evmAddress)@42161?value=1e18",
            "ethereum:\(arbitrumUSDT)@42161/transfer?address=\(evmAddress)&uint256=1e6",
        ]

        for payload in payloads {
            XCTAssertEqual(RampAddressFormat.evm.recipient(fromQRCode: payload), evmAddress, payload)
        }
    }

    func testEvmRecipientRejectsOtherFormats() {
        for payload in [tonAddress, tronAddress, solanaAddress, "alice.near", "ethereum:vitalik.eth"] {
            XCTAssertNil(RampAddressFormat.evm.recipient(fromQRCode: payload), payload)
        }
    }

    func testSolanaRecipientIsReadFromAddressAndPaymentLinks() {
        let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        let payloads = [
            solanaAddress,
            "solana:\(solanaAddress)",
            "solana:\(solanaAddress)?amount=1&spl-token=\(usdcMint)&label=Shop",
        ]

        for payload in payloads {
            XCTAssertEqual(RampAddressFormat.solana.recipient(fromQRCode: payload), solanaAddress, payload)
        }
    }

    func testSolanaRecipientRejectsOtherFormats() {
        for payload in [evmAddress, tonAddress, tronAddress, "solana:https://example.com/pay"] {
            XCTAssertNil(RampAddressFormat.solana.recipient(fromQRCode: payload), payload)
        }
    }

    func testNearRecipientAcceptsAccountIds() {
        let accounts = [
            "alice.near",
            "user_name.tg",
            "usdt.tether-token.near",
            "98793cd91a3f870fb126f66285808c7e094afcfc4eda8a970f6648cdf0dbd6de",
        ]

        for account in accounts {
            XCTAssertEqual(RampAddressFormat.near.recipient(fromQRCode: account), account, account)
        }
    }

    func testNearRecipientRejectsMalformedAccountIds() {
        let payloads = [
            "a",
            "Alice.near",
            "-alice.near",
            "alice-.near",
            "alice..near",
            ".near",
            "alice.near.",
            String(repeating: "a", count: 65),
            evmAddress,
        ]

        for payload in payloads {
            XCTAssertNil(RampAddressFormat.near.recipient(fromQRCode: payload), payload)
        }
    }

    func testTonRecipientIsReadFromAddressAndTransferLinks() {
        let payloads = [
            tonAddress,
            "ton://transfer/\(tonAddress)",
            "ton://transfer/\(tonAddress)?jetton=EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs",
            "\(tonAddress)?amount=200",
        ]

        for payload in payloads {
            XCTAssertEqual(RampAddressFormat.ton.recipient(fromQRCode: payload), tonAddress, payload)
        }
    }

    func testTonRecipientRejectsOtherFormats() {
        for payload in [evmAddress, tronAddress, solanaAddress, "\(tonAddress)?text=123456"] {
            XCTAssertNil(RampAddressFormat.ton.recipient(fromQRCode: payload), payload)
        }
    }

    func testTronRecipientAcceptsOnlyTronAddresses() {
        XCTAssertEqual(RampAddressFormat.tron.recipient(fromQRCode: tronAddress), tronAddress)
        XCTAssertEqual(RampAddressFormat.tron.recipient(fromQRCode: "\(tronAddress)?amount=200"), tronAddress)

        for payload in [evmAddress, tonAddress, solanaAddress] {
            XCTAssertNil(RampAddressFormat.tron.recipient(fromQRCode: payload), payload)
        }
    }
}

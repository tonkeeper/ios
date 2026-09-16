import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

/// The fee picker lists the battery on `isRelayerEnabled` and preselects it on `isRelayerAvailable`.
/// Keeping the two apart is what lets a wallet with too few charges still see the option — and be
/// offered a refill — instead of the option silently disappearing.
final class TransferServiceRelayerEnabledTests: XCTestCase {
    func test_jettonTransfer_isEnabledRegardlessOfCharges() {
        XCTAssertTrue(
            TransferService.isRelayerEnabled(wallet: makeWallet(), transfer: makeJettonTransfer())
        )
    }

    func test_jettonTransferWithBatteryTurnedOffForJettons_isNotEnabled() {
        let wallet = makeWallet(
            batterySettings: BatterySettings(isJettonTransactionEnable: false)
        )

        XCTAssertFalse(
            TransferService.isRelayerEnabled(wallet: wallet, transfer: makeJettonTransfer())
        )
    }

    /// The battery never pays for a plain TON transfer, so the option must not be listed for one.
    func test_tonTransfer_isNotEnabled() {
        let transfer = Transfer.ton(amount: 1, recipient: makeRecipient(), comment: nil)

        XCTAssertFalse(TransferService.isRelayerEnabled(wallet: makeWallet(), transfer: transfer))
    }

    func test_multichainSwap_followsTheSwapBatterySetting() throws {
        let transfer = try makeMultichainSwapTransfer()

        XCTAssertTrue(
            TransferService.isRelayerEnabled(wallet: makeWallet(), transfer: transfer)
        )
        XCTAssertFalse(
            TransferService.isRelayerEnabled(
                wallet: makeWallet(batterySettings: BatterySettings(isSwapTransactionEnable: false)),
                transfer: transfer
            )
        )
    }

    /// Only an aggregator's swap keeps the refund address its payload was built with; Tonkeeper's own
    /// relayed transfers redirect the excess to whoever paid the gas.
    func test_onlyMultichainSwapKeepsItsPayloadExcessAddress() throws {
        XCTAssertTrue(try makeMultichainSwapTransfer().keepsPayloadExcessAddress)
        XCTAssertFalse(makeJettonTransfer().keepsPayloadExcessAddress)
        XCTAssertFalse(
            Transfer.ton(amount: 1, recipient: makeRecipient(), comment: nil).keepsPayloadExcessAddress
        )
    }

    /// A watch-only wallet has no battery at all, whatever the per-transfer settings say.
    func test_watchOnlyWallet_isNotEnabled() throws {
        let wallet = try Wallet(
            id: "wallet-id",
            identity: WalletIdentity(network: .mainnet, kind: .Watchonly(.Resolved(Address.parse(Self.rawAddress)))),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )

        XCTAssertFalse(
            TransferService.isRelayerEnabled(wallet: wallet, transfer: makeJettonTransfer())
        )
    }
}

private extension TransferServiceRelayerEnabledTests {
    static let rawAddress = "0:0000000000000000000000000000000000000000000000000000000000000001"

    func makeMultichainSwapTransfer() throws -> Transfer {
        try .multichainSwap(
            SignRawRequest(
                messages: [
                    SignRawRequestMessage(
                        address: AnyAddress(rawAddress: Self.rawAddress),
                        amount: 100_000_000,
                        stateInit: nil,
                        payload: nil
                    ),
                ],
                validUntil: nil,
                from: Address.parse(Self.rawAddress),
                messagesVariants: nil
            )
        )
    }

    func makeWallet(batterySettings: BatterySettings = BatterySettings()) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: batterySettings
        )
    }

    func makeRecipient() -> TonRecipient {
        TonRecipient(
            recipientAddress: .raw(try! Address.parse(Self.rawAddress)),
            isMemoRequired: false,
            isScam: false
        )
    }

    func makeJettonTransfer() -> Transfer {
        .jetton(
            JettonItem(
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: try! Address.parse(Self.rawAddress),
                    fractionDigits: 6,
                    name: "USDT",
                    symbol: "USDT",
                    verification: .whitelist,
                    imageURL: nil
                ),
                walletAddress: nil
            ),
            transferAmount: 1,
            amount: 1,
            recipient: makeRecipient(),
            comment: nil
        )
    }
}

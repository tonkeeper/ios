@preconcurrency import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class WalletConnectEVMFeeTests: XCTestCase {
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let address = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    private static let passcode = "1234"

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func testGasFeeIsSignedAsItWasPriced() throws {
        let fee = try WalletConnectEVMFee(
            fee: FeeGas(
                asset: asset(.eth),
                limit: bignum(21000),
                price: bignum(3_000_000_000),
                amount: bignum(63_000_000_000_000)
            )
        )

        XCTAssertEqual(fee, WalletConnectEVMFee(amount: 63_000_000_000_000, limit: 21000, price: .gas(price: 3_000_000_000)))
        let signed = try XCTUnwrap(fee.chainKitFee(chain: .eth) as? FeeGas)
        XCTAssertEqual(
            [signed.limit, signed.price, signed.amount].map(\.description),
            ["21000", "3000000000", "63000000000000"]
        )
    }

    func testEip1559FeeKeepsTheAmountChainKitPriced() throws {
        let fee = try WalletConnectEVMFee(
            fee: FeeEip1559(
                asset: asset(.base),
                limit: bignum(100_000),
                networkPrice: bignum(1000),
                maxPrice: bignum(2000),
                minerPrice: bignum(500),
                amount: bignum(200_000_777)
            )
        )

        XCTAssertEqual(fee.amount, 200_000_777)
        let signed = try XCTUnwrap(fee.chainKitFee(chain: .base) as? FeeEip1559)
        XCTAssertEqual(
            [signed.limit, signed.networkPrice, signed.maxPrice, signed.minerPrice, signed.amount].map(\.description),
            ["100000", "1000", "2000", "500", "200000777"]
        )
    }

    func testFeeWithoutGasIsRejected() {
        XCTAssertThrowsError(try WalletConnectEVMFee(fee: FeeValue(asset: asset(.eth), amount: bignum(1))))
    }

    func testTransactionIsSignedWithTheQuotedFeeWhateverFeeTheDAppSent() async throws {
        let wallet = makeWallet()
        let mnemonicAccess = try await makeMnemonicAccess(wallet: wallet)
        let quoted = WalletConnectEVMFee(amount: 21000 * 7, limit: 21000, price: .gas(price: 7))

        let signedWithDAppFee = try await sign(
            transaction(gas: "0x5208", gasPrice: "0x3b9aca00"),
            fee: quoted,
            wallet: wallet,
            mnemonicAccess: mnemonicAccess
        )
        let signedWithoutDAppFee = try await sign(
            transaction(gas: nil, gasPrice: nil),
            fee: quoted,
            wallet: wallet,
            mnemonicAccess: mnemonicAccess
        )
        let signedWithAnotherQuote = try await sign(
            transaction(gas: nil, gasPrice: nil),
            fee: WalletConnectEVMFee(amount: 21000 * 8, limit: 21000, price: .gas(price: 8)),
            wallet: wallet,
            mnemonicAccess: mnemonicAccess
        )

        XCTAssertEqual(signedWithDAppFee, signedWithoutDAppFee)
        XCTAssertNotEqual(signedWithoutDAppFee, signedWithAnotherQuote)
    }

    func testASignedTransactionIsAnsweredAsTheRawTransactionTheWalletSigned() async throws {
        let wallet = makeWallet()
        let mnemonicAccess = try await makeMnemonicAccess(wallet: wallet)

        let signed = try await sign(
            transaction(gas: nil, gasPrice: nil),
            fee: WalletConnectEVMFee(amount: 21000 * 7, limit: 21000, price: .gas(price: 7)),
            wallet: wallet,
            mnemonicAccess: mnemonicAccess
        )

        var input = EthereumSigningInput()
        input.chainID = Data([0x01])
        input.nonce = Data([0x00])
        input.txMode = .legacy
        input.gasPrice = Data([0x07])
        input.gasLimit = Data([0x52, 0x08])
        input.toAddress = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        input.transaction.transfer.amount = Data([0x01])
        let seed = try XCTUnwrap(HDWallet(mnemonic: Self.mnemonic, passphrase: ""))
        input.privateKey = try XCTUnwrap(seed.getKeyForCoin(coin: .ethereum)).data
        let expected: EthereumSigningOutput = AnySigner.sign(input: input, coin: .ethereum)
        XCTAssertEqual(signed, "0x" + expected.encoded.map { String(format: "%02x", $0) }.joined())
    }
}

private extension WalletConnectEVMFeeTests {
    func asset(_ chain: WalletConnectChain) -> AssetCoin {
        chain.multichainChain.asChainKitChain.toAsset()
    }

    func bignum(_ value: BigUInt) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.parseString(string: value.description, base: 10)
    }

    func transaction(gas: String?, gasPrice: String?) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: Self.address,
            to: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            data: "0x",
            value: "0x1",
            nonce: "0x0",
            gas: gas,
            gasPrice: gasPrice,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }

    func sign(
        _ transaction: WalletConnectEVMTransaction,
        fee: WalletConnectEVMFee,
        wallet: Wallet,
        mnemonicAccess: MnemonicAccess
    ) async throws -> String {
        let context = WalletConnectSigningContext(
            signer: .mnemonic(passcodeProvider: { Self.passcode }),
            wallet: wallet,
            mnemonicAccess: mnemonicAccess,
            client: client,
            pendingTransactionsService: IgnoredPendingTransactions(),
            evmFee: fee
        )
        let response = try await WalletConnectEVMTransactionSigningUtilities().sign(
            transaction: transaction,
            send: false,
            chain: .eth,
            context: context
        )
        guard case let .string(signed) = response else {
            throw XCTSkip("Expected a signed raw transaction, got \(response)")
        }
        return signed
    }

    func makeMnemonicAccess(wallet: Wallet) async throws -> MnemonicAccess {
        let mnemonicAccess = MnemonicAccess.inMemory(seed: "wallet-connect-evm-fee")
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: Self.passcode
        )
        return mnemonicAccess
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet-connect-evm-fee",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "wallet-connect-evm-fee",
                addresses: [.init(chain: .eth, address: Self.address)],
                syncState: .synced
            ))
        )
    }
}

private struct IgnoredPendingTransactions: PendingTransactionsService {
    func report(_: MultichainPendingTransaction) async {}

    func flushRetained() async {}
}

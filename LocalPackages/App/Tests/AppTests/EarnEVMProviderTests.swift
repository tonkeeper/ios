@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

@MainActor
final class EarnEVMProviderTests: XCTestCase {
    func test_accountsAnswerTheActiveWalletAddress() async throws {
        let context = makeContext()

        let result = await context.handle(.accounts)

        XCTAssertEqual(try json(of: result), "[\"\(address)\"]")
    }

    func test_chainStartsOnEthereum() async throws {
        let context = makeContext()

        let chainId = await context.handle(.chainId)
        let netVersion = await context.handle(.netVersion)

        XCTAssertEqual(try json(of: chainId), "\"0x1\"")
        XCTAssertEqual(try json(of: netVersion), "\"1\"")
    }

    func test_switchingToASupportedChainChangesTheChainAndTellsThePage() async throws {
        let context = makeContext()

        let result = await context.handle(.switchChain(chainId: "0x2105"))

        XCTAssertEqual(try json(of: result), "null")
        XCTAssertEqual(context.events, [.chainChanged(chainIdHex: "0x2105")])
        let chainId = await context.handle(.chainId)
        XCTAssertEqual(try json(of: chainId), "\"0x2105\"")
    }

    func test_switchingToTheCurrentChainSendsNoEvent() async throws {
        let context = makeContext()

        let result = await context.handle(.switchChain(chainId: "0x1"))

        XCTAssertEqual(try json(of: result), "null")
        XCTAssertTrue(context.events.isEmpty)
    }

    func test_switchingToAChainTheWalletDoesNotSupportIsRefused() async throws {
        let context = makeContext()

        let result = await context.handle(.switchChain(chainId: "0x89"))

        XCTAssertEqual(code(of: result), 4902)
        XCTAssertTrue(context.events.isEmpty)
        let chainId = await context.handle(.chainId)
        XCTAssertEqual(try json(of: chainId), "\"0x1\"")
    }

    func test_switchingToAChainTheWalletHasNoAddressOnIsRefused() async throws {
        let context = makeContext(chains: [.eth])

        let result = await context.handle(.switchChain(chainId: "0x2105"))

        XCTAssertEqual(code(of: result), 4902)
        XCTAssertTrue(context.events.isEmpty)
        let chainId = await context.handle(.chainId)
        XCTAssertEqual(try json(of: chainId), "\"0x1\"")
    }

    func test_unsupportedMethodsAreRejected() async {
        let context = makeContext()

        let result = await context.handle(.unsupported(method: "eth_call"))

        XCTAssertEqual(code(of: result), 4200)
    }

    func test_walletWithoutAnEVMAddressIsUnauthorized() async {
        let context = makeContext(chains: [])

        let result = await context.handle(.accounts)

        XCTAssertEqual(code(of: result), 4100)
    }

    func test_transactionsReachTheSignerOnTheCurrentChain() async throws {
        let context = makeContext()
        context.signer.result = .success(.string("0xsigned"))

        let result = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(try json(of: result), "\"0xsigned\"")
        let request = try XCTUnwrap(context.signer.requests.first)
        XCTAssertEqual(request.method, .ethSendTransaction)
        XCTAssertEqual(request.chain, .eth)
        XCTAssertEqual(request.walletId, "wallet")
        XCTAssertEqual(request.payload, .evmTransaction(transaction, send: true))
    }

    func test_messagesAreSignedWithTheAddressThePagePassed() async throws {
        let context = makeContext()
        context.signer.result = .success(.string("0xsignature"))

        _ = await context.handle(.personalSign(message: "0x68656c6c6f", address: address))

        let request = try XCTUnwrap(context.signer.requests.first)
        XCTAssertEqual(request.method, .personalSign)
        XCTAssertEqual(
            request.payload,
            .signMessage(WalletConnectSignMessage(address: address, message: "0x68656c6c6f", kind: .personal))
        )
    }

    func test_cancelledPasscodeIsAUserRejection() async {
        let context = makeContext()
        context.signer.result = .failure(.canceled)

        let result = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(code(of: result), 4001)
    }

    func test_failedSignatureIsAnInternalError() async {
        let context = makeContext()
        context.signer.result = .failure(.failedToSign(reason: "no"))

        let result = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(code(of: result), -32603)
    }

    func test_sentTransactionIsReportedWithTheChainItWasSentOn() async {
        let context = makeContext()
        context.signer.result = .success(.string("0xhash"))
        _ = await context.handle(.switchChain(chainId: "0x2105"))

        _ = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(
            context.sentTransactions,
            [SentTransaction(walletId: "wallet", chain: .base, transaction: transaction)]
        )
    }

    func test_declinedTransactionIsNotReported() async {
        let context = makeContext()
        context.signer.result = .failure(.canceled)

        _ = await context.handle(.sendTransaction(transaction))

        XCTAssertTrue(context.sentTransactions.isEmpty)
    }

    func test_signedMessageIsNotReportedAsATransaction() async {
        let context = makeContext()
        context.signer.result = .success(.string("0xsignature"))

        _ = await context.handle(.personalSign(message: "0x68656c6c6f", address: address))

        XCTAssertTrue(context.sentTransactions.isEmpty)
    }

    func test_everyStageKeepsThePageTheRequestCameFrom() async {
        let context = makeContext()
        context.signer.result = .failure(.failedToSend(reason: "nonce too low"))
        let page = URL(string: "https://vaults.fyi/earn/base/0xvault")

        _ = await context.handle(.sendTransaction(transaction), pageURL: page)

        XCTAssertEqual(context.signingEvents.map(\.pageURL), [page, page])
    }

    func test_signedTransactionReportsTheRequestAndItsSuccess() async {
        let context = makeContext()
        context.signer.result = .success(.string("0xhash"))

        _ = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(context.signingEvents, [
            EarnSigningEvent(method: .ethSendTransaction, chain: .eth, pageURL: nil, stage: .requested),
            EarnSigningEvent(method: .ethSendTransaction, chain: .eth, pageURL: nil, stage: .signed),
        ])
    }

    func test_cancelledPasscodeIsReportedAsARejection() async {
        let context = makeContext()
        context.signer.result = .failure(.canceled)

        _ = await context.handle(.personalSign(message: "0x68656c6c6f", address: address))

        XCTAssertEqual(context.signingEvents.map(\.stage), [.requested, .rejected])
    }

    func test_signerFailureIsReportedWithItsError() async {
        let context = makeContext()
        context.signer.result = .failure(.failedToSend(reason: "nonce too low"))

        _ = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(
            context.signingEvents.map(\.stage),
            [.requested, .failed(.signer(.failedToSend(reason: "nonce too low")))]
        )
    }

    func test_signingWithoutAnEVMAccountIsReportedAsNoAccount() async {
        let context = makeContext(chains: [])

        _ = await context.handle(.sendTransaction(transaction))

        XCTAssertEqual(context.signingEvents.map(\.stage), [.requested, .failed(.noAccount)])
        XCTAssertTrue(context.signer.requests.isEmpty)
    }

    func test_readsAreNotReportedAsSigning() async {
        let context = makeContext()

        _ = await context.handle(.accounts)
        _ = await context.handle(.chainId)
        _ = await context.handle(.switchChain(chainId: "0x2105"))

        XCTAssertTrue(context.signingEvents.isEmpty)
    }

    func test_activeWalletChangeTellsThePage() async {
        let context = makeContext()
        let wallet = context.walletsStore.getState().wallets[0]

        context.walletsStore.sendEvent(.didChangeActiveWallet(from: wallet, to: wallet))

        await context.waitForEvents(count: 1)
        XCTAssertEqual(context.events, [.accountsChanged([address])])
    }

    func test_evmAddressArrivingAfterThePageAskedTellsThePage() async {
        let context = makeContext(chains: [])
        let wallet = context.walletsStore.getState().wallets[0]
        _ = await context.handle(.accounts)

        await context.walletsStore.setWalletMultichain(
            wallet: wallet,
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: [MultichainWalletAddress(chain: .eth, address: address)]
                )
            )
        )

        await context.waitForEvents(count: 1)
        XCTAssertEqual(context.events, [.accountsChanged([address])])
    }

    func test_multichainUpdateKeepingTheAccountsSendsNoEvent() async {
        let context = makeContext()
        let wallet = context.walletsStore.getState().wallets[0]
        _ = await context.handle(.accounts)

        await context.walletsStore.setWalletMultichain(wallet: wallet, multichain: wallet.multichain)

        await context.waitForEvents(count: 1)
        XCTAssertTrue(context.events.isEmpty)
    }
}

private extension EarnEVMProviderTests {
    var address: String {
        "0x1111111111111111111111111111111111111111"
    }

    var transaction: WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: address,
            to: "0x2222222222222222222222222222222222222222",
            data: "0x",
            value: "0x0",
            nonce: nil,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }

    func makeContext(chains: [MultichainChain] = [.eth, .base]) -> Context {
        let wallet = makeWallet(addresses: chains.map { MultichainWalletAddress(chain: $0, address: address) })
        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: KeeperInfoRepositoryStub(
                keeperInfo: KeeperInfo(
                    wallets: [wallet],
                    currentWallet: wallet,
                    currency: .defaultCurrency,
                    securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
                    appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo, hidesDustBalances: false),
                    country: .auto
                )
            )
        )
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let signer = SignerSpy()
        let provider = EarnEVMProvider(
            dapp: WalletConnectDapp(name: "Earn", url: "https://vaults.fyi", description: "", iconURL: nil),
            walletsStore: walletsStore,
            sign: { _, request throws(WalletConnectSigningError) in
                signer.requests.append(request)
                return try signer.result.get()
            }
        )
        return Context(provider: provider, walletsStore: walletsStore, signer: signer)
    }

    func makeWallet(addresses: [MultichainWalletAddress]) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: "multichain-wallet", addresses: addresses))
        )
    }

    func json(of result: DappMessageHandlerResult) throws -> String {
        guard case let .success(data) = result else {
            throw ResultError(result: result)
        }
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    func code(of result: DappMessageHandlerResult) -> Int? {
        guard case let .rejected(code, _) = result else { return nil }
        return code
    }
}

@MainActor
private final class Context {
    let provider: EarnEVMProvider
    let walletsStore: WalletsStore
    let signer: SignerSpy
    private(set) var events = [EVMProviderEvent]()
    private(set) var sentTransactions = [SentTransaction]()
    private(set) var signingEvents = [EarnSigningEvent]()

    init(provider: EarnEVMProvider, walletsStore: WalletsStore, signer: SignerSpy) {
        self.provider = provider
        self.walletsStore = walletsStore
        self.signer = signer
        provider.onEvent = { [weak self] event in
            self?.events.append(event)
        }
        provider.onSigning = { [weak self] event in
            self?.signingEvents.append(event)
        }
        provider.onTransactionSent = { [weak self] wallet, chain, transaction in
            self?.sentTransactions.append(SentTransaction(walletId: wallet.id, chain: chain, transaction: transaction))
        }
    }

    func handle(_ request: EVMProviderRequest, pageURL: URL? = nil) async -> DappMessageHandlerResult {
        await withCheckedContinuation { continuation in
            provider.handle(request, pageURL: pageURL) { result in
                continuation.resume(returning: result)
            }
        }
    }

    func waitForEvents(count: Int) async {
        let deadline = Date().addingTimeInterval(2)
        while events.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private struct SentTransaction: Equatable {
    let walletId: String
    let chain: WalletConnectChain
    let transaction: WalletConnectEVMTransaction
}

private final class SignerSpy {
    var result: Result<WalletConnectResponseValue, WalletConnectSigningError> = .success(.null)
    var requests = [WalletConnectSessionRequest]()
}

private struct ResultError: Error {
    let result: DappMessageHandlerResult
}

private struct StubError: Error {}

private struct KeeperInfoRepositoryStub: KeeperInfoRepository {
    final class Storage {
        var keeperInfo: KeeperInfo?

        init(keeperInfo: KeeperInfo?) {
            self.keeperInfo = keeperInfo
        }
    }

    private let storage: Storage

    init(keeperInfo: KeeperInfo?) {
        storage = Storage(keeperInfo: keeperInfo)
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo = storage.keeperInfo else {
            throw StubError()
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        storage.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        storage.keeperInfo = nil
    }
}

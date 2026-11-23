@testable import App
@testable import KeeperCore
import LedgerKit
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class LedgerConfirmViewModelTests: XCTestCase {
    func testAMissingTonAppTurnsItsStepRed() async {
        let failed = expectation(description: "TON app step failed")
        failed.assertForOverFulfill = false
        let viewModel = makeViewModel { _ in
            ledger(replies: [dashboard, Data([0x68, 0x07])])
        }
        viewModel.didUpdateModel = { model in
            if model.contentViewModel.stepModels.contains(where: { $0.state == .failed }) {
                failed.fulfill()
            }
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [failed], timeout: 1)
        viewModel.stopTasks()
    }

    func testALedgerHoldingAnotherWalletIsToldBeforeTheProof() async {
        let closed = expectation(description: "sheet closed")
        let viewModel = makeViewModel { _ in
            ledger(replies: [tonApp, Data(repeating: 0x02, count: 32) + Data([0x90, 0x00])])
        }
        var toasts: [String] = []
        viewModel.showToast = { toasts.append($0.title) }
        viewModel.didCancel = { closed.fulfill() }

        viewModel.viewDidLoad()
        await fulfillment(of: [closed], timeout: 1)

        XCTAssertEqual(toasts, [TKLocales.LedgerSteps.otherWallet])
    }

    func testADroppedLinkIsConnectedAgain() async {
        let connections = Connections()
        let reconnected = expectation(description: "connected again")
        let viewModel = makeViewModel { _ in
            let count = await connections.open()
            if count == 2 {
                reconnected.fulfill()
            }
            return LedgerLink(
                exchange: { _ in Data([0x55, 0x15]) },
                disconnected: AsyncStream { disconnection in
                    if count == 1 {
                        disconnection.finish()
                    }
                },
                close: {}
            )
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [reconnected], timeout: 1)
        viewModel.stopTasks()
    }

    private func makeViewModel(connect: @escaping @Sendable (UUID) async throws -> LedgerLink) -> LedgerConfirmViewModelImplementation {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32))
        let device = Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Ledger Stax", accountIndex: 0)
        let wallet = Wallet(
            id: "ledger",
            identity: WalletIdentity(network: .mainnet, kind: .Ledger(publicKey, .v4R2, device)),
            metaData: WalletMetaData(label: "Ledger", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: nil
        )
        return LedgerConfirmViewModelImplementation(
            confirmItem: .signatureData(TonConnect.SignatureData(
                address: try! WalletV4R2(publicKey: publicKey.data).address(),
                domain: TonConnect.Domain(domain: "example.com"),
                timestamp: 0,
                payload: "payload"
            )),
            wallet: wallet,
            ledgerDevice: device,
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { _ in } },
                connect: connect
            ),
            knownJettonResolver: nil
        )
    }
}

private let dashboard = Data([0x01, 0x05]) + Data("BOLOS".utf8) + Data([0x05]) + Data("1.0.0".utf8) + Data([0x90, 0x00])
private let tonApp = Data([0x01, 0x03]) + Data("TON".utf8) + Data([0x05]) + Data("2.7.0".utf8) + Data([0x90, 0x00])

/// A connected Ledger that gives `replies` in order, then an unknown status.
private func ledger(replies: [Data]) -> LedgerLink {
    let replies = Replies(replies)
    return LedgerLink(exchange: { _ in await replies.next() }, disconnected: AsyncStream { _ in }, close: {})
}

private actor Replies {
    private var replies: [Data]

    init(_ replies: [Data]) {
        self.replies = replies
    }

    func next() -> Data {
        replies.isEmpty ? Data([0x6F, 0x00]) : replies.removeFirst()
    }
}

private actor Connections {
    private var count = 0

    func open() -> Int {
        count += 1
        return count
    }
}

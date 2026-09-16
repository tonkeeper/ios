import Foundation
import HTTPTypes
@testable import KeeperCore
import MultichainAPI
import OpenAPIRuntime
import XCTest

final class MultichainClientAPIRoutingTests: XCTestCase {
    func test_healthcheckUsesThePublicClient() async {
        let context = RoutingContext()

        _ = try? await context.api.healthcheck()

        XCTAssertEqual(context.publicRecorder.operationIDs, [MultichainAPI.Operations.healthcheck.id])
        XCTAssertEqual(context.deviceRecorder.operationIDs, [])
        XCTAssertEqual(context.walletRecorder.operationIDs, [])
    }

    func test_operationsInheritingGlobalSecurityUseTheDeviceScopedClient() async {
        let context = RoutingContext()

        _ = try? await context.api.searchAssets(
            currencies: ["usd"],
            chain: nil,
            search: nil,
            sort: .marketCap,
            limit: nil,
            cursor: nil
        )
        _ = try? await context.api.broadcastTx(chain: .ton, signedTransaction: Data())
        _ = try? await context.api.getFees(chain: .ton)
        _ = try? await context.api.getWalletChallenge()
        _ = try? await context.api.forcePickRaffleWinners(
            raffleId: "raffle-id",
            walletId: nil,
            prizeId: nil
        )

        XCTAssertEqual(context.publicRecorder.operationIDs, [])
        XCTAssertEqual(
            context.deviceRecorder.operationIDs,
            [
                MultichainAPI.Operations.searchAssets.id,
                MultichainAPI.Operations.broadcastTx.id,
                MultichainAPI.Operations.getFees.id,
                MultichainAPI.Operations.getWalletChallenge.id,
                MultichainAPI.Operations.forcePickRaffleWinners.id,
            ]
        )
        XCTAssertEqual(context.walletRecorder.operationIDs, [])
    }

    func test_raffleOperationsUseTheWalletScopedClient() async {
        let context = RoutingContext()

        _ = try? await context.api.getWalletRaffles(
            walletId: "wallet-id",
            lang: nil,
            ids: nil,
            debugNow: nil,
            isNewUser: false
        )
        try? await context.api.completeRaffleMigration(walletId: "wallet-id")
        try? await context.api.markRaffleImport(walletId: "wallet-id", importedWalletId: "imported-wallet-id")

        XCTAssertEqual(context.publicRecorder.operationIDs, [])
        XCTAssertEqual(context.deviceRecorder.operationIDs, [])
        XCTAssertEqual(
            context.walletRecorder.operationIDs,
            [
                MultichainAPI.Operations.getWalletRaffles.id,
                MultichainAPI.Operations.completeWalletRaffleMigration.id,
                MultichainAPI.Operations.markWalletRaffleImport.id,
            ]
        )
    }
}

private final class RoutingContext {
    let publicRecorder = OperationRecorder()
    let deviceRecorder = OperationRecorder()
    let walletRecorder = OperationRecorder()

    lazy var api = MultichainClientAPIImplementation(
        multichainAPIClient: { [publicRecorder] in Self.client(recorder: publicRecorder) },
        deviceScopedAPIClient: { [deviceRecorder] in Self.client(recorder: deviceRecorder) },
        walletScopedAPIClient: { [walletRecorder] _ in Self.client(recorder: walletRecorder) }
    )

    private static func client(recorder: OperationRecorder) -> MultichainAPI.Client {
        MultichainAPI.Client(
            serverURL: URL(string: "https://multi.tonkeeper.com")!,
            transport: UnusedTransport(),
            middlewares: [StopAndRecordMiddleware(recorder: recorder)]
        )
    }
}

private final class OperationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = [String]()

    var operationIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ operationID: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(operationID)
    }
}

private struct StopAndRecordMiddleware: ClientMiddleware {
    private struct Stop: Error {}

    let recorder: OperationRecorder

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        recorder.append(operationID)
        throw Stop()
    }
}

private struct UnusedTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        XCTFail("transport should not be reached for \(operationID)")
        return (HTTPResponse(status: .internalServerError), nil)
    }
}

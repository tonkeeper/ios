@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsDepositStatusMappingTests: XCTestCase {
    func testMissingBackendStepsAreNotInferredFromTransportEvidence() throws {
        for stage: PerpsDepositStage in [.sourceSending, .gatewaySending, .awaitingDelivery, .registrationPending, .registeredPending, .failed, .refunded] {
            XCTAssertNil(try mapped(stage: stage, route: .crosschainSwap, sourceTxHash: "0x1", depositId: "dep").step)
        }
    }

    func testOnlyAnAggregatorFillHasTheConvertingStep() throws {
        XCTAssertTrue(try mapped(stage: .credited, route: .directGateway).skipsConversion)
        XCTAssertTrue(try mapped(stage: .registeredPending, route: .crosschainSwap, symbol: "USDC", executionId: "funxyz_1").skipsConversion)
        XCTAssertFalse(try mapped(stage: .credited, route: .crosschainSwap, executionId: "exec-1").skipsConversion)
        XCTAssertFalse(try mapped(stage: .registeredPending, route: .crosschainSwap, symbol: "USDC", executionId: "exec-1").skipsConversion)
    }

    func testAConvertingStepWithoutOneShowsAsAdding() throws {
        XCTAssertEqual(try mapped(stage: .registeredPending, route: .directGateway, step: .converting).step, .adding)
        XCTAssertEqual(try mapped(stage: .registeredPending, route: .crosschainSwap, executionId: "funxyz_1", step: .converting).step, .adding)
        XCTAssertEqual(try mapped(stage: .registeredPending, route: .crosschainSwap, executionId: "exec-1", step: .converting).step, .converting)
        XCTAssertEqual(try mapped(stage: .registeredPending, route: .directGateway, step: .sending).step, .sending)
    }

    func testJournalsWrittenWithoutBackendStepsStillDecode() throws {
        let operation = try XCTUnwrap(status(stage: .registeredPending))
        XCTAssertNil(operation.step)
        let legacy = Data(#"{"stage":"registeredPending","route":"crosschainSwap","beneficiary":"0xabc","sourceAsset":{"assetId":"ton/mainnet/coin","symbol":"TON","decimals":9},"sourceAmountUnits":"1000000000","targetAsset":{"assetId":"eth/mainnet/erc20/usdc","symbol":"USDC","decimals":6}}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(PerpsPendingDeposit.self, from: legacy).pendingStep)
    }

    func testADraftIsNotAStatusAndAMissingEstimateStaysMissing() throws {
        XCTAssertNil(status(stage: .draft))
        XCTAssertNil(try mapped(stage: .sourceSending, estimated: 0).estimatedDurationSeconds)
        XCTAssertEqual(try mapped(stage: .sourceSending, estimated: 90).estimatedDurationSeconds, 90)
    }

    func testDelayUsesTheEstimateAndNothingElse() throws {
        let created = Date(timeIntervalSince1970: 1000)
        let pending = try mapped(stage: .sourceSending, estimated: 60, createdAt: created)
        XCTAssertTrue(pending.isDelayed(at: created.addingTimeInterval(61)))
        XCTAssertFalse(pending.isDelayed(at: created.addingTimeInterval(60)))
        XCTAssertFalse(try mapped(stage: .sourceSending, estimated: nil, createdAt: created).isDelayed(at: created.addingTimeInterval(10000)))
    }

    private func mapped(
        stage: PerpsDepositStage,
        route: PerpsDepositRoute = .directGateway,
        sourceTxHash: String? = nil,
        depositId: String? = nil,
        symbol: String = "TON",
        executionId: String? = nil,
        step: PerpsDepositStatus.Step? = nil,
        estimated: Int? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1000)
    ) throws -> PerpsDepositStatus {
        try XCTUnwrap(status(
            stage: stage,
            route: route,
            sourceTxHash: sourceTxHash,
            depositId: depositId,
            symbol: symbol,
            executionId: executionId,
            step: step,
            estimated: estimated,
            createdAt: createdAt
        ))
    }

    private func status(
        stage: PerpsDepositStage,
        route: PerpsDepositRoute = .directGateway,
        sourceTxHash: String? = nil,
        depositId: String? = nil,
        symbol: String = "TON",
        executionId: String? = nil,
        step: PerpsDepositStatus.Step? = nil,
        estimated: Int? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1000)
    ) -> PerpsDepositStatus? {
        var deposit = PerpsPendingDeposit(
            stage: stage,
            route: route,
            beneficiary: "0xabc",
            sourceAsset: PerpsFundingAsset(assetId: "ton/mainnet/coin", symbol: symbol, decimals: 9),
            sourceAmountUnits: "1000000000",
            targetAsset: PerpsFundingAsset(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6)
        )
        deposit.sourceTxHash = sourceTxHash
        deposit.depositId = depositId
        deposit.executionId = executionId
        deposit.pendingStep = step
        deposit.estimatedDurationSeconds = estimated
        return PerpsPendingFundingOperation(
            operationId: "op",
            walletId: "wallet",
            walletIdentity: "identity",
            environment: "test",
            createdAtMillis: Int64(createdAt.timeIntervalSince1970 * 1000),
            details: .deposit(deposit)
        ).depositStatus
    }
}

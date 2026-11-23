import PerpsModels
import SwiftUI
import TKUIKit

extension PerpsDepositStatus {
    static var previewSending: Self {
        sample(id: "sending", step: .sending, estimated: 120)
    }

    static var previewConverting: Self {
        sample(id: "converting", step: .converting, estimated: 60)
    }

    static var previewAdding: Self {
        sample(id: "adding", step: .adding, estimated: 60)
    }

    static let previewDelayed = sample(
        id: "delayed",
        createdAt: Date(timeIntervalSinceNow: -180),
        step: .converting,
        estimated: 60
    )
    static let previewCredited = sample(id: "credited", state: .completed, credited: "707.19", step: .adding)
    static let previewFailed = sample(
        id: "failed",
        createdAt: Date(timeIntervalSince1970: 1_761_990_000),
        state: .refunded,
        step: .converting
    )
    static let previewDeposited = sample(
        id: "deposited",
        createdAt: Date(timeIntervalSince1970: 1_761_980_000),
        state: .completed,
        credited: "707.19",
        step: .adding
    )

    private static func sample(
        id: String,
        createdAt: Date = Date(timeIntervalSinceNow: -5),
        state: State = .pending,
        credited: String? = nil,
        step: Step?,
        estimated: Int? = nil
    ) -> PerpsDepositStatus {
        PerpsDepositStatus(
            id: id,
            createdAt: createdAt,
            sourceAmount: "350",
            sourceSymbol: "GRAM",
            sourceNetwork: "ton",
            expectedAmount: "707.19",
            creditedAmount: credited,
            estimatedDurationSeconds: estimated,
            state: state,
            step: step
        )
    }
}

final class PerpsDepositStatusPreviewStore: PerpsAccountStoring {
    let deposits: [PerpsDepositStatus]
    let activity: PerpsFundingActivity?

    init(deposits: [PerpsDepositStatus], activity: PerpsFundingActivity? = nil) {
        self.deposits = deposits
        self.activity = activity
    }

    func addChangeObserver<T: AnyObject>(_: T, onChange _: @escaping (T) -> Void) {}
    func currentWalletState() -> PerpsWalletAccountState {
        .inactive
    }

    func resolveIfNeeded() {}
    func refresh() {}

    func fundingActivity() -> PerpsFundingActivity {
        activity ?? PerpsFundingActivity(deposits: deposits)
    }

    func lifecycle(marketId _: Int64) -> PerpsMarketLifecycle {
        .flat
    }

    func marketExtras(marketId _: Int64) -> PerpsMarketExtras? {
        nil
    }

    func loadMarketExtras(marketId _: Int64) {}
    func releaseMarketExtras(marketId _: Int64) {}
    func subscribePositions(cadence _: PerpsPositionsCadence) {}
    func unsubscribePositions(cadence _: PerpsPositionsCadence) {}
}

@MainActor
private func previewModel(_ deposits: [PerpsDepositStatus]) -> PerpsDepositStatusViewModel {
    PerpsDepositStatusViewModel(
        accountStore: PerpsDepositStatusPreviewStore(deposits: deposits),
        format: .preview
    )
}

@available(iOS 17.0, *)
#Preview("Rows", traits: .sizeThatFitsLayout) {
    VStack(spacing: 24) {
        depositRow([.previewSending])
        depositRow([.previewConverting])
        depositRow([.previewAdding])
        depositRow([.previewDelayed])
        creditedRow()
        depositRow([.previewFailed])
        depositRow([.previewSending, .previewConverting])
        depositRow([.previewSending, .previewDelayed])
    }
    .padding(16)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

#Preview("Sending") {
    depositSheet(.previewSending)
}

#Preview("Converting") {
    depositSheet(.previewConverting)
}

#Preview("Adding") {
    depositSheet(.previewAdding)
}

#Preview("Taking longer") {
    depositSheet(.previewDelayed)
}

#Preview("Completed") {
    depositSheet(.previewCredited)
}

#Preview("Refunded") {
    depositSheet(.previewFailed)
}

#Preview("All added") {
    allAddedRow()
        .padding(16)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Deposit Statuses") {
    PerpsDepositStatusesView(model: previewModel([
        .previewSending,
        .previewFailed,
        .previewDeposited,
    ]), onClose: {})
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@MainActor
private func depositSheet(_ deposit: PerpsDepositStatus) -> some View {
    PerpsDepositStatusDetailsView(model: previewModel([deposit]), depositId: deposit.id, onClose: {})
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@MainActor
private func creditedRow() -> some View {
    let pending = PerpsDepositStatus.previewSending
    let model = previewModel([pending])
    model.apply([
        PerpsDepositStatus(
            id: pending.id,
            createdAt: pending.createdAt,
            sourceAmount: pending.sourceAmount,
            sourceSymbol: pending.sourceSymbol,
            sourceNetwork: pending.sourceNetwork,
            expectedAmount: pending.expectedAmount,
            creditedAmount: "707.19",
            estimatedDurationSeconds: pending.estimatedDurationSeconds,
            state: .completed,
            step: .adding
        ),
    ])
    return depositCard(model)
}

@MainActor
private func allAddedRow() -> some View {
    let sending = PerpsDepositStatus.previewSending
    let converting = PerpsDepositStatus.previewConverting
    let model = previewModel([sending, converting])
    model.apply([sending, converting].map { deposit in
        PerpsDepositStatus(
            id: deposit.id,
            createdAt: deposit.createdAt,
            sourceAmount: deposit.sourceAmount,
            sourceSymbol: deposit.sourceSymbol,
            sourceNetwork: deposit.sourceNetwork,
            expectedAmount: deposit.expectedAmount,
            creditedAmount: "707.19",
            estimatedDurationSeconds: deposit.estimatedDurationSeconds,
            state: .completed,
            step: .adding
        )
    })
    return depositCard(model)
}

@MainActor
private func depositRow(_ deposits: [PerpsDepositStatus]) -> some View {
    depositCard(previewModel(deposits))
}

@MainActor
private func depositCard(_ model: PerpsDepositStatusViewModel) -> some View {
    VStack(spacing: -12) {
        RoundedRectangle(cornerRadius: 16)
            .fill(TKColor.backgroundContent)
            .frame(height: 76)
        PerpsDepositStatusRow(model: model)
    }
}

#Preview("Waiting for backend") {
    let deposit = PerpsDepositStatus(
        id: "unknown-step", createdAt: Date(), sourceAmount: "350", sourceSymbol: "GRAM",
        sourceNetwork: "ton", expectedAmount: "707.19", estimatedDurationSeconds: 120
    )
    depositSheet(deposit)
}

#Preview("Direct USDC") {
    let deposit = PerpsDepositStatus(
        id: "direct", createdAt: Date(), sourceAmount: "707.19", sourceSymbol: "USDC",
        sourceNetwork: "eth", expectedAmount: "707.19", creditedAmount: "707.19",
        state: .completed, skipsConversion: true
    )
    depositSheet(deposit)
}

#Preview("Transferring USDC") {
    let deposit = PerpsDepositStatus(
        id: "usdc", createdAt: Date(), sourceAmount: "350", sourceSymbol: "USDC",
        sourceNetwork: "tron", expectedAmount: "349.5", estimatedDurationSeconds: 120, step: .converting
    )
    depositSheet(deposit)
}

@available(iOS 17.0, *)
#Preview("Loaders Light", traits: .sizeThatFitsLayout) {
    loaderRows().tkPreviewTheme(.light)
}

@available(iOS 17.0, *)
#Preview("Loaders Dark", traits: .sizeThatFitsLayout) {
    loaderRows().tkPreviewTheme(.dark)
}

@available(iOS 17.0, *)
#Preview("Grouped failures", traits: .sizeThatFitsLayout) {
    failedGroupRow()
        .frame(width: 390)
        .padding(16)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@MainActor
private func failedGroupRow() -> some View {
    let pending: [PerpsDepositStatus] = [.previewSending, .previewConverting]
    let model = previewModel(pending)
    model.apply(pending.map { deposit in
        PerpsDepositStatus(
            id: deposit.id,
            createdAt: deposit.createdAt,
            sourceAmount: deposit.sourceAmount,
            sourceSymbol: deposit.sourceSymbol,
            sourceNetwork: deposit.sourceNetwork,
            expectedAmount: deposit.expectedAmount,
            state: .failed,
            step: deposit.step
        )
    })
    return depositCard(model)
}

@MainActor
private func loaderRows() -> some View {
    VStack(spacing: 24) {
        depositRow([.previewSending])
        depositRow([.previewConverting])
        depositRow([.previewAdding])
        creditedRow()
    }
    .frame(width: 390)
    .padding(16)
    .background(.backgroundPage)
}

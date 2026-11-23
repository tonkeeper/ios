extension TransferError {
    /// A broadcast that failed, worded alike for TonAPI and the battery and wherever a flow broadcasts, so
    /// analytics reads the same refusal as one. A relayer that named its reason keeps it as `refusal`.
    static func broadcastFailure(_ error: Error, count: Int, transferType: TransferType) -> TransferError {
        let kind = count == 1 ? "single" : "batch"
        return .sendFailed(
            message: "failed to \(kind) \(transferType.analyticsName) send due to error: \(error.analyticsReason)",
            refusal: RelayerRefusal(error)
        )
    }
}

struct MultichainSwapConfirmationDisplay {
    struct TemporaryReserve {
        let value: String
        let hint: String
    }

    let rateLine: String
    let slippageLine: String
    let minimumReceivedLine: String
    let minimumReceivedFiatLine: String?
    let networkFeeTitle: String
    let networkFeeValue: String
    let networkFeeMethod: String
    let canPickFeeMethod: Bool
    let networkFeeSubtitle: String
    /// Nothing can pay the fee, and the subtitle says what is missing.
    let isNetworkFeeShortage: Bool
    let temporaryReserve: TemporaryReserve?
}

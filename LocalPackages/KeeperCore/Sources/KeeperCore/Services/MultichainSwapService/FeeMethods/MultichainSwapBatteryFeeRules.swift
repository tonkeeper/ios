import BigInt

/// The decisions the relayed fee methods make about a swap, kept pure so they can be tested without
/// a `TransferService`.
enum MultichainSwapBatteryFeeRules {
    /// What the relayer may be asked to move for this swap, or `nil` when no relayed method must pay
    /// for it: there must be nothing to approve first, and the wallet must be a mainnet regular one
    /// whose address on that chain is known.
    static func relayedAsset(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        requiresApproval: Bool,
        isTRXOnlyRegion: Bool
    ) -> MultichainSwapRelayedAsset? {
        guard !requiresApproval else {
            return nil
        }
        guard wallet.kind == .regular, wallet.network.isMainnet else {
            return nil
        }
        guard case let .multichain(state) = wallet.multichain,
              let asset = MultichainSwapRelayedAsset(sourceAsset),
              state.address(for: asset.chain) != nil
        else {
            return nil
        }
        // A TRX-only region bills TRON resources in TRX and hides every relayed method, exactly as the
        // USDT send path does; offering one here would contradict the send screen for the same asset.
        guard asset.chain != .tron || !isTRXOnlyRegion else {
            return nil
        }
        return asset
    }

    /// Battery on top of that: the relayer has to be switched on remotely and by the wallet itself.
    /// The wallet's own switch is checked here rather than per chain, because a user who turned
    /// battery off for swaps means it for every chain. The GRAM instant fee is not charges, so it is
    /// not gated on any of this — the same way the TRON send screen offers it.
    static func isBatteryAllowed(
        wallet: Wallet,
        isBatteryEnabled: Bool,
        isBatterySendEnabled: Bool
    ) -> Bool {
        isBatteryEnabled
            && isBatterySendEnabled
            && wallet.isBatteryEnable
            && wallet.batterySettings.isSwapTransactionEnable
    }

    /// A method that cannot cover its own fee is still offered, marked insufficient, so the picker can
    /// send the user to a refill — but `MultichainSwapFeeSelection` never preselects it.
    static func option(
        charges: Int?,
        excessCharges: Int?,
        availableCharges: BatteryChargesAvailability
    ) -> MultichainSwapFeeOption {
        // An estimate without a price is what a wallet that never used battery gets back. Hiding the
        // method here is what left the picker offering the chain's coin alone, so the row stays and
        // carries the refill instead.
        guard let charges, charges > 0 else {
            return MultichainSwapFeeOption(cost: .batteryUnpriced)
        }
        return MultichainSwapFeeOption(
            cost: .batteryCharges(
                count: charges,
                excess: excessCharges,
                isInsufficient: isInsufficient(charges: charges, availableCharges: availableCharges)
            )
        )
    }

    /// A balance that could not be read is the same unknown the option was priced under, so the
    /// relayer gets to refuse it. A wallet battery cannot pay for at all is not that unknown, and is
    /// refused here for the same reason `option` marks it insufficient.
    static func requireCharges(
        _ charges: Int,
        available: BatteryChargesAvailability,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) {
        switch available {
        case .unknown:
            return
        case .unavailable:
            throw .preparationFailed(
                kind: .insufficientBalance,
                reason: "battery cannot pay for swap payload \(payloadId)"
            )
        case let .available(availableCharges):
            guard availableCharges < charges else {
                return
            }
            throw .preparationFailed(
                kind: .insufficientBalance,
                reason: "battery charges no longer cover swap payload \(payloadId)"
            )
        }
    }

    /// The relayer bills the resources it burns now, not the ones the confirmation screen priced. A
    /// re-quote that outgrew the confirmed one goes back for a fresh confirmation rather than
    /// debiting more charges than the user agreed to.
    static func requireQuote(
        _ charges: Int,
        confirmedCharges: Int,
        available: BatteryChargesAvailability,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) {
        // `option` reads a non-positive count as no price at all, so the same count must not read
        // here as a quote that merely came in under the confirmed one.
        guard charges > 0 else {
            throw .preparationFailed(
                kind: .networkError,
                reason: "battery priced swap payload \(payloadId) at \(charges) charges"
            )
        }
        try requireCharges(charges, available: available, payloadId: payloadId)
        guard charges > confirmedCharges else {
            return
        }
        throw .preparationFailed(
            kind: .unknown,
            reason: "battery now charges \(charges) for swap payload \(payloadId), above the confirmed \(confirmedCharges)"
        )
    }

    /// The relayer prices its instant fee in GRAM against a TON rate that keeps moving, so a re-quote
    /// slightly above the confirmed one is drift rather than a different price, and refusing it would
    /// only send the user back to confirm the same swap. Past the tolerance the difference stops being
    /// noise and needs a fresh confirmation. Charges have no equivalent: they are whole units, and one
    /// more of them is a real one more.
    static let gramRequoteTolerancePercent: BigUInt = 5

    static func requireGramQuote(
        _ amountNano: BigUInt,
        confirmedAmountNano: BigUInt,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) {
        let tolerated = confirmedAmountNano + confirmedAmountNano * gramRequoteTolerancePercent / 100
        guard amountNano > tolerated else {
            return
        }
        throw .preparationFailed(
            kind: .unknown,
            reason: "the relayer now asks \(amountNano) nano for swap payload \(payloadId), above the \(tolerated) the confirmed \(confirmedAmountNano) tolerates"
        )
    }

    private static func isInsufficient(
        charges: Int,
        availableCharges: BatteryChargesAvailability
    ) -> Bool {
        switch availableCharges {
        case .unavailable:
            return true
        case .unknown:
            return false
        case let .available(available):
            return available < charges
        }
    }
}

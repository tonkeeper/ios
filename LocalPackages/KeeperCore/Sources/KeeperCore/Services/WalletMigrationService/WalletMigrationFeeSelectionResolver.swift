public struct WalletMigrationFeeSelection: Equatable {
    public let ton: WalletMigrationPrepareResult.FeeMethod?
    public let tron: WalletMigrationTronPrepareResult.FeeMethod?

    public init(
        ton: WalletMigrationPrepareResult.FeeMethod?,
        tron: WalletMigrationTronPrepareResult.FeeMethod?
    ) {
        self.ton = ton
        self.tron = tron
    }
}

public enum WalletMigrationTronFeeShortage: Equatable {
    case trx
    case battery
}

public enum WalletMigrationFeeSelectionResolver {
    public static func preferred(
        ton: WalletMigrationPrepareResult?,
        tron: WalletMigrationTronPrepareResult?,
        availableBatteryCharges: Int?
    ) -> WalletMigrationFeeSelection {
        let tonMethods = orderedTonMethods(ton)
        let tronMethods = orderedTronMethods(tron)
        let fallbackTon = tonMethods.first { $0?.isBattery == false } ?? tonMethods[0]
        let fallbackTron = tronMethods.first { tronMethod in
            let selection = WalletMigrationFeeSelection(ton: fallbackTon, tron: tronMethod)
            return canDefaultTo(
                selection: selection,
                availableBatteryCharges: availableBatteryCharges
            ) && !isTronMethodInsufficient(
                tronMethod,
                tron: tron,
                tonMethod: fallbackTon,
                availableBatteryCharges: availableBatteryCharges
            )
        } ?? tronMethods[0]
        let fallback = WalletMigrationFeeSelection(
            ton: fallbackTon,
            tron: fallbackTron
        )

        for tonMethod in tonMethods {
            for tronMethod in tronMethods {
                let selection = WalletMigrationFeeSelection(
                    ton: tonMethod,
                    tron: tronMethod
                )
                guard canDefaultTo(
                    selection: selection,
                    availableBatteryCharges: availableBatteryCharges
                ) else {
                    continue
                }
                if !isInsufficient(
                    selection: selection,
                    ton: ton,
                    tron: tron,
                    availableBatteryCharges: availableBatteryCharges
                ) {
                    return selection
                }
            }
        }

        return fallback
    }

    public static func isInsufficient(
        selection: WalletMigrationFeeSelection,
        ton: WalletMigrationPrepareResult?,
        tron: WalletMigrationTronPrepareResult?,
        availableBatteryCharges: Int?
    ) -> Bool {
        isTonMethodInsufficient(
            selection.ton,
            ton: ton,
            tronMethod: selection.tron,
            availableBatteryCharges: availableBatteryCharges
        ) || isTronMethodInsufficient(
            selection.tron,
            tron: tron,
            tonMethod: selection.ton,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    /// Whether any offered method can pay the TON leg on its own. The TRON leg never adds
    /// to the shared Battery demand here: skipping it is always possible via the TON-only
    /// continue, and it is exactly the pairing with the lowest charge requirement.
    public static func hasPayableTonMethod(
        ton: WalletMigrationPrepareResult?,
        availableBatteryCharges: Int?
    ) -> Bool {
        guard let ton else { return false }
        return orderedTonMethods(ton).contains { tonMethod in
            !isTonMethodInsufficient(
                tonMethod,
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: availableBatteryCharges
            )
        }
    }

    public static func isTonMethodInsufficient(
        _ method: WalletMigrationPrepareResult.FeeMethod?,
        ton: WalletMigrationPrepareResult?,
        tronMethod: WalletMigrationTronPrepareResult.FeeMethod?,
        availableBatteryCharges: Int?
    ) -> Bool {
        guard let ton else { return false }
        guard let method else { return ton.isSelfPaidTonInsufficient }

        switch method {
        case let .ton(amountNano):
            return ton.isSelfPaidTonInsufficient
                || ton.availableTonNano.map { $0 < amountNano } == true
        case .battery:
            guard ton.hasBatteryExecutionPath else {
                return true
            }
            return hasInsufficientBattery(
                tonMethod: method,
                tronMethod: tronMethod,
                availableBatteryCharges: availableBatteryCharges
            )
        }
    }

    public static func isTronMethodInsufficient(
        _ method: WalletMigrationTronPrepareResult.FeeMethod?,
        tron: WalletMigrationTronPrepareResult?,
        tonMethod: WalletMigrationPrepareResult.FeeMethod?,
        availableBatteryCharges: Int?
    ) -> Bool {
        tronShortage(
            method,
            tron: tron,
            tonMethod: tonMethod,
            availableBatteryCharges: availableBatteryCharges
        ) != nil
    }

    /// The TRON leg never affects the verdict: it can always be dropped via the soft-shortage
    /// Continue, and any pairing only raises the shared Battery demand above the standalone one.
    /// Battery with an unknown balance is not a way out here — sponsored routes stay unavailable
    /// until the client confirms that the wallet has enough charges for the selected path.
    public static func isTonMethodPayable(
        _ method: WalletMigrationPrepareResult.FeeMethod,
        ton: WalletMigrationPrepareResult,
        availableBatteryCharges: Int?
    ) -> Bool {
        if method.isBattery, !ton.hasBatteryExecutionPath {
            return false
        }
        if method.isBattery, availableBatteryCharges == nil {
            return false
        }
        return hasPayableCompletion(
            tonCandidates: [method],
            tronCandidates: [nil],
            ton: ton,
            tron: nil,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    public static func isTronMethodPayable(
        _ method: WalletMigrationTronPrepareResult.FeeMethod,
        ton: WalletMigrationPrepareResult?,
        tron: WalletMigrationTronPrepareResult,
        availableBatteryCharges: Int?
    ) -> Bool {
        // A TON leg that no method can pay is dropped by the soft-shortage Continue flow, so it
        // must not drag every pairing down; the TRON method is then judged standalone.
        let payableTon = ton.flatMap { candidate in
            isTonLegPayable(candidate, availableBatteryCharges: availableBatteryCharges)
                ? candidate
                : nil
        }
        return hasPayableCompletion(
            tonCandidates: candidateMethods(payableTon?.availableFeeMethods),
            tronCandidates: [method],
            ton: payableTon,
            tron: tron,
            availableBatteryCharges: availableBatteryCharges
        )
    }

    public static func tronShortage(
        _ method: WalletMigrationTronPrepareResult.FeeMethod?,
        tron: WalletMigrationTronPrepareResult?,
        tonMethod: WalletMigrationPrepareResult.FeeMethod?,
        availableBatteryCharges: Int?
    ) -> WalletMigrationTronFeeShortage? {
        guard let method, let tron else { return nil }

        if tron.hasInsufficientTRX(for: method) {
            return .trx
        }
        if case .battery = method,
           hasInsufficientBattery(
               tonMethod: tonMethod,
               tronMethod: method,
               availableBatteryCharges: availableBatteryCharges
           )
        {
            return .battery
        }
        return nil
    }

    public static func requiredBatteryCharges(
        tonMethod: WalletMigrationPrepareResult.FeeMethod?,
        tronMethod: WalletMigrationTronPrepareResult.FeeMethod?
    ) -> Int {
        let tonCharges: Int = if case let .battery(charges) = tonMethod {
            max(charges, 0)
        } else {
            0
        }
        let tronCharges: Int = if case let .battery(charges) = tronMethod {
            max(charges, 0)
        } else {
            0
        }
        let (sum, overflow) = tonCharges.addingReportingOverflow(tronCharges)
        return overflow ? .max : sum
    }
}

private extension WalletMigrationFeeSelectionResolver {
    /// A method is payable only when some complete TON + TRON selection containing it is
    /// sufficient, so the shared Battery budget between the legs is always accounted for.
    static func hasPayableCompletion(
        tonCandidates: [WalletMigrationPrepareResult.FeeMethod?],
        tronCandidates: [WalletMigrationTronPrepareResult.FeeMethod?],
        ton: WalletMigrationPrepareResult?,
        tron: WalletMigrationTronPrepareResult?,
        availableBatteryCharges: Int?
    ) -> Bool {
        tonCandidates.contains { tonMethod in
            tronCandidates.contains { tronMethod in
                !isInsufficient(
                    selection: WalletMigrationFeeSelection(ton: tonMethod, tron: tronMethod),
                    ton: ton,
                    tron: tron,
                    availableBatteryCharges: availableBatteryCharges
                )
            }
        }
    }

    static func candidateMethods<Method>(_ methods: [Method]?) -> [Method?] {
        guard let methods, !methods.isEmpty else { return [nil] }
        return methods.map(Optional.some)
    }

    static func isTonLegPayable(
        _ ton: WalletMigrationPrepareResult,
        availableBatteryCharges: Int?
    ) -> Bool {
        candidateMethods(ton.availableFeeMethods).contains { method in
            !isTonMethodInsufficient(
                method,
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: availableBatteryCharges
            )
        }
    }

    static func canDefaultTo(
        selection: WalletMigrationFeeSelection,
        availableBatteryCharges: Int?
    ) -> Bool {
        guard availableBatteryCharges == nil else { return true }
        return selection.ton?.isBattery != true && selection.tron?.isBattery != true
    }

    static func hasInsufficientBattery(
        tonMethod: WalletMigrationPrepareResult.FeeMethod?,
        tronMethod: WalletMigrationTronPrepareResult.FeeMethod?,
        availableBatteryCharges: Int?
    ) -> Bool {
        let required = requiredBatteryCharges(
            tonMethod: tonMethod,
            tronMethod: tronMethod
        )
        guard required > 0 else {
            return false
        }
        guard let availableBatteryCharges else {
            return true
        }
        return availableBatteryCharges < required
    }

    static func orderedTonMethods(
        _ result: WalletMigrationPrepareResult?
    ) -> [WalletMigrationPrepareResult.FeeMethod?] {
        guard let result, !result.availableFeeMethods.isEmpty else {
            return [nil]
        }
        return ordered(
            result.availableFeeMethods,
            preferred: result.availableFeeMethods.first(where: \.isBattery)
        ).map(Optional.some)
    }

    static func orderedTronMethods(
        _ result: WalletMigrationTronPrepareResult?
    ) -> [WalletMigrationTronPrepareResult.FeeMethod?] {
        guard let result, !result.availableFeeMethods.isEmpty else {
            return [nil]
        }
        let preferred = result.availableFeeMethods.first { method in
            guard case let .trx(amountSun) = method else { return true }
            return result.availableTRXSun >= amountSun
        }
        return ordered(
            result.availableFeeMethods,
            preferred: preferred
        ).map(Optional.some)
    }

    static func ordered<Method: Equatable>(
        _ methods: [Method],
        preferred: Method?
    ) -> [Method] {
        guard let preferred, methods.contains(preferred) else {
            return methods
        }
        return [preferred] + methods.filter { $0 != preferred }
    }
}

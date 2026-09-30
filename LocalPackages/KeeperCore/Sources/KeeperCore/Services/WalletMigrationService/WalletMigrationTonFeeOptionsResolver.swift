import BigInt
import Foundation

struct WalletMigrationTonFeeOptionsResolver {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func resolve(
        selfTotalFees: UInt64,
        batteryTotalFees: UInt64?,
        hasSponsoredBatteryPath: Bool,
        allowBatteryQuoteWithoutSponsoredPath: Bool,
        wallet: Wallet
    ) async -> [WalletMigrationPrepareResult.FeeMethod] {
        guard selfTotalFees > 0 || (batteryTotalFees ?? 0) > 0 else { return [] }

        var methods: [WalletMigrationPrepareResult.FeeMethod] = []
        if selfTotalFees > 0 {
            methods.append(.ton(amountNano: selfTotalFees))
        }

        guard wallet.isBatteryEnable else {
            return methods
        }

        let isBatteryEnable = await configuration.isBatteryEnable(network: wallet.network)
        guard isBatteryEnable else { return methods }

        // v3/v4 cannot prepare sponsored txs — quote Battery from the self-paid plan so Deposit
        // can open a refill. That stub stays intentionally insufficient (no execution path);
        // refill still tops up Battery for other flows. v5+ must not get the stub: a GRAM-only
        // sweep has nothing Battery can sponsor, and Deposit misleads when charges are available.
        // When a sponsored prepare exists, never fold the unsponsored GRAM sweep into the quote.
        let batteryChargeBasis = Self.batteryChargeBasis(
            selfTotalFees: selfTotalFees,
            batteryTotalFees: batteryTotalFees,
            hasSponsoredBatteryPath: hasSponsoredBatteryPath,
            allowBatteryQuoteWithoutSponsoredPath: allowBatteryQuoteWithoutSponsoredPath
        )
        guard let batteryChargeBasis, batteryChargeBasis > 0 else { return methods }

        let calculation = BatteryCalculation(configuration: configuration)
        guard let requiredCharges = calculation.calculateCharges(tonAmount: BigUInt(batteryChargeBasis)),
              requiredCharges > 0
        else {
            return methods
        }

        methods.append(.battery(charges: requiredCharges))
        return methods
    }

    /// Pure fee-basis choice for the Battery row — kept separate so the legacy-stub vs
    /// sponsored-path branches can be unit-tested without a live `Configuration`.
    static func batteryChargeBasis(
        selfTotalFees: UInt64,
        batteryTotalFees: UInt64?,
        hasSponsoredBatteryPath: Bool,
        allowBatteryQuoteWithoutSponsoredPath: Bool
    ) -> UInt64? {
        if let batteryTotalFees {
            return batteryTotalFees
        }
        if hasSponsoredBatteryPath {
            return nil
        }
        if allowBatteryQuoteWithoutSponsoredPath, selfTotalFees > 0 {
            return selfTotalFees
        }
        return nil
    }

    static func preferred(
        methods: [WalletMigrationPrepareResult.FeeMethod]
    ) -> WalletMigrationPrepareResult.FeeMethod? {
        methods.first(where: \.isBattery) ?? methods.first
    }
}

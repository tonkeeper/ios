struct BatteryChargesReader {
    private let batteryService: BatteryService
    private let batteryCalculation: BatteryCalculation
    private let offersMigration: (Wallet) async -> Bool

    init(
        batteryService: BatteryService,
        batteryCalculation: BatteryCalculation,
        offersMigration: @escaping (Wallet) async -> Bool = { _ in false }
    ) {
        self.batteryService = batteryService
        self.batteryCalculation = batteryCalculation
        self.offersMigration = offersMigration
    }

    func availableCharges(wallet: Wallet) async -> BatteryChargesAvailability {
        if await offersMigration(wallet) { return .unknown }
        return await currentCharges(wallet: wallet)
    }

    func currentCharges(wallet: Wallet) async -> BatteryChargesAvailability {
        let batteryBalance: BatteryBalance
        do {
            batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet)
        } catch let error as BatteryAuthorizationError {
            switch error {
            case .unavailable, .legacyProofUnavailable: return .unavailable
            case .deviceSessionFailure: return .unknown
            }
        } catch {
            return .unknown
        }
        guard let charges = batteryCalculation.calculateAvailableCharges(balance: batteryBalance) else {
            return .unknown
        }
        return .available(charges)
    }
}

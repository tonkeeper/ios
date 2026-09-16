struct BatteryChargesReader {
    private let batteryService: BatteryService
    private let batteryCalculation: BatteryCalculation

    init(batteryService: BatteryService, batteryCalculation: BatteryCalculation) {
        self.batteryService = batteryService
        self.batteryCalculation = batteryCalculation
    }

    func availableCharges(wallet: Wallet) async -> BatteryChargesAvailability {
        let batteryBalance: BatteryBalance
        do {
            batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet)
        } catch is BatteryAuthorizationError {
            return .unavailable
        } catch {
            return .unknown
        }
        guard let charges = batteryCalculation.calculateAvailableCharges(balance: batteryBalance) else {
            return .unknown
        }
        return .available(charges)
    }
}

enum OptimisticToggleSync {
    static func run(
        isOn: Bool,
        currentIsOn: () -> Bool,
        setIsOn: (Bool) async -> Void,
        sync: () async -> Bool
    ) async -> Bool {
        let previousIsOn = currentIsOn()
        await setIsOn(isOn)
        guard await sync() else {
            let latestIsOn = currentIsOn()
            if latestIsOn == isOn, latestIsOn != previousIsOn {
                await setIsOn(previousIsOn)
            }
            return false
        }
        return true
    }
}

import KeeperCore

extension MultichainHistoryViewModelImplementation {
    func persistHistoryFilters(to appSettingsStore: AppSettingsStore) {
        onHistoryFiltersChange = { [weak appSettingsStore] hidesDustTransactions in
            appSettingsStore?.setHidesDustTransactions(hidesDustTransactions)
        }
    }
}

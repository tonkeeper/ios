@MainActor
final class LazyNetworkFeePickerDataSource {
    private let load: () async -> NetworkFeePickerContent

    init(load: @escaping () async -> NetworkFeePickerContent) {
        self.load = load
    }
}

extension LazyNetworkFeePickerDataSource: NetworkFeePickerDataSource {
    var content: NetworkFeePickerContent? {
        nil
    }

    func loadContent() async -> NetworkFeePickerContent {
        await load()
    }
}

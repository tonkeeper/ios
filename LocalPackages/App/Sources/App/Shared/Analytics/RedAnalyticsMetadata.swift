import Foundation
import TKLogging

extension RedAnalyticsMetadata {
    var asJsonString: String? {
        let payload: [String: Any] = reduce(into: [:]) { partialResult, element in
            guard let value = element.value else {
                return
            }
            partialResult[element.key.rawValue] = value
        }
        guard !payload.isEmpty else {
            return nil
        }
        guard JSONSerialization.isValidJSONObject(payload) else {
            Log.w("red analytics metadata payload is not a valid json")
            return nil
        }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        } catch {
            Log.w("failed to serialize red analytics metadata payload due to error: \(error)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

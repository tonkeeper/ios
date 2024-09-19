import Foundation

struct AppSettings: Equatable {
  let isSetupFinished: Bool
  let isSecureMode: Bool
}

extension AppSettings: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isSetupFinished = (try? container.decode(Bool.self, forKey: .isSetupFinished)) ?? false
    self.isSecureMode = (try? container.decode(Bool.self, forKey: .isSecureMode)) ?? false
  }
}

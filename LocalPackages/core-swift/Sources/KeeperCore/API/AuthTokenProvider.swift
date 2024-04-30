import Foundation
import TonAPI
import OpenAPIRuntime
import HTTPTypes

final class AuthTokenProvider: ClientMiddleware {
  private let remoteConfigurationStore: ConfigurationStore
    
    init(remoteConfigurationStore: ConfigurationStore) {
        self.remoteConfigurationStore = remoteConfigurationStore
    }
  
  func intercept(_ request: HTTPTypes.HTTPRequest,
                 body: OpenAPIRuntime.HTTPBody?,
                 baseURL: URL,
                 operationID: String,
                 next: @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL)
                 async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?))
  async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var mutableRequest = request
    let configuration = (try? await remoteConfigurationStore.getConfiguration()) ?? .empty
    mutableRequest
      .headerFields
      .append(
        .init(name: .authorization,
              value: "Bearer \(configuration.tonApiV2Key)")
      )
    return try await next(mutableRequest, body, baseURL)
  }
}

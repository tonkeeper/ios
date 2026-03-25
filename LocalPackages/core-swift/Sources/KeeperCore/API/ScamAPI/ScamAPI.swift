import Foundation
import TonSwift

protocol ScamAPI {
    func changeSuspiciousState(
        _ nft: NFT,
        isScam: Bool,
        network: Network
    ) async throws
    func reportScamTransaction(
        _ eventID: String,
        recipient: Address,
        network: Network
    ) async throws
}

extension ScamAPI {
    func reportScamTransaction(
        _ eventID: String,
        recipient: Address
    ) async throws {
        try await reportScamTransaction(eventID, recipient: recipient, network: .mainnet)
    }
}

struct ScamAPIImplementation: ScamAPI {
    private let urlSession: URLSession
    private let configuration: Configuration

    init(
        urlSession: URLSession,
        configuration: Configuration
    ) {
        self.urlSession = urlSession
        self.configuration = configuration
    }

    enum ScamRequestURL: Swift.Error {
        case incorrectURL
    }

    private struct SuspiciousNFT: Codable {
        let is_scam: Bool
    }

    private struct ScamTX: Codable {
        let recipient: String
    }

    func changeSuspiciousState(
        _ nft: NFT,
        isScam: Bool,
        network: Network = .mainnet
    ) async throws {
        guard let scamAPIUrl = await configuration.scamApiURL(network: network) else {
            throw ScamRequestURL.incorrectURL
        }
        var composedURL = scamAPIUrl
        let rawAddress = nft.address.toRaw()
        composedURL = composedURL.appendingPathComponent("v1/report/\(rawAddress)")
        let bodyItem = SuspiciousNFT(is_scam: isScam)
        let encoder = JSONEncoder()

        let httpBody = try encoder.encode(bodyItem)

        var request = URLRequest(url: composedURL)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await urlSession.data(for: request)
    }

    func reportScamTransaction(_ eventID: String, recipient: Address, network: Network = .mainnet) async throws {
        guard let scamAPIUrl = await configuration.scamApiURL(network: network) else {
            throw ScamRequestURL.incorrectURL
        }
        var composedURL = scamAPIUrl
        composedURL = composedURL.appendingPathComponent("v1/report/tx/\(eventID)")
        let bodyItem = ScamTX(recipient: recipient.toRaw())
        let encoder = JSONEncoder()
        let httpBody = try encoder.encode(bodyItem)
        var request = URLRequest(url: composedURL)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await urlSession.data(for: request)
    }
}

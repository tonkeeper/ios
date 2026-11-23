import Foundation
import KeeperCore
import KeeperCoreComponents
import LedgerKit
import TKLocalize
import TKLogging

extension LedgerSteps where Value == Data {
    /// Signs an EVM transaction in the Ethereum app. A token transfer names the token when Ledger's
    /// registry knows it; otherwise the app has to allow blind signing.
    static func ethereumTransaction(_ request: EVMDeviceSignRequest, account: Int) -> LedgerSteps<Data> {
        LedgerSteps(
            stages: [.init(app: .ethereum, prompt: TKLocales.LedgerConfirm.Steps.Confirm.description)],
            run: { session in
                let token = await LedgerTokenRegistry.descriptor(contract: request.tokenContract, chainId: request.chainId)
                return try await session.run(on: .ethereum) { link in
                    if let token {
                        do {
                            try await link.provideEthereumToken(descriptor: token.data, signature: token.signature)
                        } catch let error as LedgerStatusError where !error.isLocked {
                            Log.w("Ledger refused the token descriptor, signing without it", error: error)
                        } catch LedgerTransportError.invalidRequest {
                            Log.w("Ledger token descriptor is malformed, signing without it")
                        }
                    }
                    do {
                        return try await link.signEthereumTransaction(
                            request.transaction,
                            path: EthereumApp.path(account: account),
                            chainId: request.chainId
                        )
                    } catch let error as LedgerStatusError where error.isInvalidData {
                        // 6A80 means both "blind signing is off" and malformed data; the app setting tells them apart.
                        guard try await link.ethereumBlindSigningEnabled() else {
                            throw LedgerStepsFailure(message: TKLocales.LedgerSteps.blindSigning)
                        }
                        throw error
                    }
                }
            }
        )
    }
}

/// Ledger's token registry (CAL): the signed descriptor that lets the Ethereum app name an ERC-20 token.
enum LedgerTokenRegistry {
    struct Descriptor: Sendable {
        let data: Data
        let signature: Data
    }

    /// `nil` when there is no token, or the registry does not know it or does not answer in time.
    static func descriptor(contract: String?, chainId: UInt64) async -> Descriptor? {
        guard let contract else {
            return nil
        }
        var components = URLComponents(string: "https://global.api.prd.ledger.com/cal/v1/tokens")
        components?.queryItems = [
            URLQueryItem(name: "contract_address", value: contract.lowercased()),
            URLQueryItem(name: "chain_id", value: String(chainId)),
            URLQueryItem(name: "output", value: "descriptor"),
            URLQueryItem(name: "ref", value: "branch:main"),
        ]
        guard let url = components?.url else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: 4)
        request.setValue("keeper-ios", forHTTPHeaderField: "X-Ledger-Client-Version")
        do {
            let (body, _) = try await URLSession.shared.data(for: request)
            guard let entry = try JSONDecoder().decode([Entry].self, from: body).first,
                  let data = Data(strictHex: entry.descriptor.data),
                  let signature = Data(strictHex: entry.descriptor.signatures.prod)
            else {
                Log.w("Ledger token registry has no descriptor for \(contract) on chain \(chainId)")
                return nil
            }
            return Descriptor(data: data, signature: signature)
        } catch {
            Log.w("Ledger token registry failed for \(contract) on chain \(chainId)", error: error)
            return nil
        }
    }

    private struct Entry: Decodable {
        struct Payload: Decodable {
            struct Signatures: Decodable {
                let prod: String
            }

            let data: String
            let signatures: Signatures
        }

        let descriptor: Payload
    }
}

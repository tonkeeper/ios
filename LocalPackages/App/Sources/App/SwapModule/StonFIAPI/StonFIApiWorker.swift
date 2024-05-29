//
//  StonFIApiWorker.swift
//
//
//  Created by Marina on 27.05.2024.
//

import Foundation

class StonFIApiWorker {
    func fetchAssets(completion: @escaping (Result<[StonFIAsset], Error>) -> Void) {
        guard let url = URL(string: "https://api.ston.fi/v1/assets") else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let decoder = JSONDecoder()
                let assetListResponse = try decoder.decode(StonFIAssetListResponse.self, from: data)
                completion(.success(assetListResponse.assetList))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    func simulateSwap(swapRequest: StonFISwapRequest, completion: @escaping (Result<StonFISwapSimulation, Error>) -> Void) {
        let urlString = "https://api.ston.fi/v1/swap/simulate?offer_address=\(swapRequest.offerAddress)&ask_address=\(swapRequest.askAddress)&units=\(swapRequest.units)&slippage_tolerance=\(swapRequest.slippageTolerance)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }

            do {
                let decoder = JSONDecoder()
                let swapSimulation = try decoder.decode(StonFISwapSimulation.self, from: data)
                completion(.success(swapSimulation))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}

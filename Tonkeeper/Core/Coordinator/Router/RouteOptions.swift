//
//  RouteOptions.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

struct RouteOptions {
    static var `default`: RouteOptions {
        .init(isAnimated: true)
    }
    
    let isAnimated: Bool
}

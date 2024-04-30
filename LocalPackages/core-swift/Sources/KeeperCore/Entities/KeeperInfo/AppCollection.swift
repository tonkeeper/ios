import Foundation

struct AppCollection: Codable {
    let connected: [WalletID: AppConnection]
    let recent: [AppID]
    let pinned: [AppID]
}

typealias AppID = String
struct AppConnection: Codable {
    let id: AppID
    // TBD: a bunch of ton connect stuff
    let sessionID: Data
    
    // TODO: notif preferences
    let notifications: Bool
}

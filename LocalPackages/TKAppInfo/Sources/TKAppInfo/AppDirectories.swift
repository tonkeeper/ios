import Foundation

public enum AppDirectories {
    public static var documents: URL {
        if #available(iOS 16.0, *) {
            return URL.documentsDirectory
        } else {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
    }

    public static var sharedCache: URL {
        if let appGroupId = InfoProvider.appGroupName(),
           let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        {
            return containerURL
        }
        return documents
    }
}

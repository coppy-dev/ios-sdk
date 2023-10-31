import Foundation
import UIKit

public protocol CoppyUpdatable: ObservableObject, Encodable {
    init()
    func update(_ obj: [String: Any])
}

struct CoppyPlistRoot: Decodable {
    let ContentKey: String
}

struct CoppyConfig {
    let contentKey: String
    let contentUrl: String
    let savedContentTagKey: String
    let appliedContentTagKey: String
    let snapshotUrl: URL
}

private var _coppyContent: (any CoppyUpdatable)? = nil
private var _coppyContentClass: AnyClass? = nil

public class Coppy<T: CoppyUpdatable> {
    init() {}

    static public func initialize(_ contentClass: T.Type) {
        if _coppyContent == nil { _coppyContent = Coppy.content(contentClass) }
        if _coppyContentClass == nil { _coppyContentClass = contentClass }
        
        NotificationCenter.default.addObserver(self, selector: #selector(Coppy.checkForUpdatesInBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "Coppy:CheckContentUpdate")
        Task(priority: .background, operation: {
            await checkForUpdates(contentClass)
            await UIApplication.shared.endBackgroundTask(taskId)
        })
    }
    
    static public func content(_ contentClass: T.Type) -> T {
        let content = _coppyContent
        guard let content = content as? T else {
            return Coppy.loadContent(contentClass)
        }
        return content
    }
    
    @objc static private func checkForUpdatesInBackground() {
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "Coppy:CheckContentUpdate")
        let contentClass: AnyClass? = _coppyContentClass
        guard let contentClass = contentClass as? T.Type else { return }
        Task(priority: .background, operation: {
            await checkForUpdates(contentClass)
            await UIApplication.shared.endBackgroundTask(taskId)
        })
    }
    
    static private func checkForUpdates(_ contentClass: T.Type) async {
        guard let config = loadConfig() else { return }
        guard let url = URL(string: config.contentUrl) else { return }
        let session = URLSession.shared
        
        // First, we send a "HEAD" request to check the latest "E-Tag" of the content, with our
        // local version. If it is the same, we are not going to reload the content
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        
        guard let (_, headResponse) = try? await session.data(for: headRequest) else { return }
        let savedETag = UserDefaults.standard.string(forKey: config.savedContentTagKey)
        let appliedETag = UserDefaults.standard.string(forKey: config.appliedContentTagKey)
        
        var data: Data? = nil
        var eTag: String? = nil
        if savedETag != (headResponse as? HTTPURLResponse)?.allHeaderFields["Etag"] as? String {
            // We have a newer version of content on the server, than the saved one.
            // We will download a new content, apply it and save it
            let request = URLRequest(url: url)
            if let (responseData, response) = try? await session.data(for: request) {
                data = responseData
                eTag = (response as? HTTPURLResponse)?.allHeaderFields["Etag"] as? String
            }
        } else if appliedETag != savedETag {
            // This app has the latest content version saved, but it wasn't applied
            // to the app.
            // We are going to update the app content based on the saved one.
            data = try? Data(contentsOf: config.snapshotUrl)
            eTag = savedETag
        }
        
        guard let data = data else { return }
        updateContent(data, contentClass: contentClass, eTag: eTag)
    }
    
    static func loadConfig () -> CoppyConfig? {
        guard let configUrl = Bundle.main.url(forResource: "Coppy", withExtension:"plist") else { return nil }
        guard let data = try? Data(contentsOf: configUrl) else { return nil }
        guard let key = try? PropertyListDecoder().decode(CoppyPlistRoot.self, from: data).ContentKey else { return nil }
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {return nil}
        
        guard let folderUrl = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let url = folderUrl.appendingPathComponent("coppy.\(key).\(appVersion)").appendingPathExtension("json")
        
        return CoppyConfig(
            contentKey: key,
            contentUrl: "https://content.coppy.app/\(key)/content",
            savedContentTagKey: "Coppy-saved-content-\(key)",
            appliedContentTagKey: "Coppy-applied-content-\(key)",
            snapshotUrl: url
        )
    }
    
    static private func loadContent(_ contentClass: T.Type) -> T {
        let content = contentClass.init()
        guard let config = Coppy.loadConfig() else { return content }
        
        guard let data = try? Data(contentsOf: config.snapshotUrl) else { return content }
        guard let savedContent = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else { return content }
        
        content.update(savedContent)
        return content
    }
    
    static private func saveContent(_ content: T, eTag: String?) {
        guard let config = Coppy.loadConfig() else { return }
        Task(priority: .utility, operation: {
            guard let data = try? JSONEncoder().encode(content) else { return }
            try data.write(to: config.snapshotUrl)
            if let eTag = eTag {
                UserDefaults.standard.set(eTag, forKey: config.savedContentTagKey)
            }
        })
    }
    
    static private func updateContent(_ newContent: Data, contentClass: T.Type, eTag: String?) {
        guard let updates = try? JSONSerialization.jsonObject(with: newContent, options: .fragmentsAllowed) as? [String: Any] else { return }
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .background {
                Coppy.content(contentClass).update(updates)
                
                guard let config = Coppy.loadConfig(), let eTag = eTag else { return }
                UserDefaults.standard.set(eTag, forKey: config.appliedContentTagKey)
            }
        }
        
        guard let config = Coppy.loadConfig() else { return }
        let savedETag = UserDefaults.standard.string(forKey: config.savedContentTagKey)
        
        if savedETag != eTag {
            // We are using load content, so it gives a new instance of the content class,
            // that is not used in the app yet. So the instance of the content class that is
            // actually used in the app does not get updated in foreground. only in background.
            let savedContent = Coppy.loadContent(contentClass)
            savedContent.update(updates)
            saveContent(savedContent, eTag: eTag)
        }
    }
}

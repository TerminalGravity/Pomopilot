import Foundation

struct DebugHelper {
    static func printDirectoryInfo() {
        // Print documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        print("Documents Directory: \(documentsPath?.path ?? "Not available")")
        
        // Print temporary directory
        let tempPath = FileManager.default.temporaryDirectory
        print("Temporary Directory: \(tempPath.path)")
        
        // Print bundle directory
        print("Bundle Directory: \(Bundle.main.bundlePath)")
        
        // List contents of bundle
        do {
            let bundleContents = try FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath)
            print("Bundle Contents: \(bundleContents)")
        } catch {
            print("Error listing bundle contents: \(error)")
        }
        
        // Check UserDefaults
        print("UserDefaults contains timerSettings: \(UserDefaults.standard.object(forKey: "timerSettings") != nil)")
        print("UserDefaults contains savedSessions: \(UserDefaults.standard.object(forKey: "savedSessions") != nil)")
    }
} 
import Foundation

struct DebugHelper {
    static func printDirectoryInfo() {
        // Print current directory
        print("Current Directory: \(FileManager.default.currentDirectoryPath)")
        
        // Print document directory
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("Document Directory: \(documentDirectory.path)")
        }
        
        // Print bundle directory
        print("Bundle Directory: \(Bundle.main.bundlePath)")
        
        // Print if Gemini API key is configured
        #if DEBUG
        if let apiKeyClass = NSClassFromString("Pomopilot.GeminiAPIManager") as? NSObject.Type,
           let apiKey = apiKeyClass.value(forKey: "apiKey") as? String {
            print("Gemini API Key: \(apiKey.isEmpty ? "Not configured" : "Configured")")
        } else {
            print("Gemini API Key: Could not check (class not loaded)")
        }
        #endif
        
        // Print UserDefaults data size estimate
        let keys = ["timerSettings", "savedSessions"]
        var totalSize = 0
        
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key) {
                totalSize += data.count
                print("UserDefaults - \(key): \(data.count) bytes")
            }
        }
        
        print("Total UserDefaults size: \(totalSize) bytes")
    }
} 
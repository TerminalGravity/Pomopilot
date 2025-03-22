import SwiftUI

@main
struct PomopilotApp: App {
    @StateObject private var timerManager = TimerManager()
    @StateObject private var sessionManager = SessionManager()
    
    init() {
        // Print debug information to help troubleshoot file access issues
        print("=== Debug Info ===")
        DebugHelper.printDirectoryInfo()
        print("==================")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(sessionManager)
        }
    }
} 
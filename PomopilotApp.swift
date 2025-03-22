import SwiftUI

@main
struct PomopilotApp: App {
    @StateObject private var timerManager = TimerManager()
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(sessionManager)
        }
    }
} 
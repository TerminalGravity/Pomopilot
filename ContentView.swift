import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(0)
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
} 
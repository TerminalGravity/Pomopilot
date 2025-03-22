import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var workDuration: Double
    @State private var shortBreakDuration: Double
    @State private var longBreakDuration: Double
    @State private var cyclesBeforeLongBreak: Double
    @State private var delayBetweenTimers: Double
    @State private var useVoiceInteraction: Bool
    @State private var showSavedBanner = false
    
    init() {
        let settings = TimerSettings.load()
        _workDuration = State(initialValue: Double(settings.workDuration))
        _shortBreakDuration = State(initialValue: Double(settings.shortBreakDuration))
        _longBreakDuration = State(initialValue: Double(settings.longBreakDuration))
        _cyclesBeforeLongBreak = State(initialValue: Double(settings.cyclesBeforeLongBreak))
        _delayBetweenTimers = State(initialValue: Double(settings.delayBetweenTimers))
        _useVoiceInteraction = State(initialValue: settings.useVoiceInteraction)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Work Timer")) {
                    VStack {
                        HStack {
                            Text("Duration: \(Int(workDuration)) min")
                            Spacer()
                            Text("\(Int(workDuration))")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Slider(value: $workDuration, in: 1...60, step: 1) {
                            Text("Work Duration")
                        }
                    }
                }
                
                Section(header: Text("Break Timers")) {
                    VStack {
                        HStack {
                            Text("Short Break: \(Int(shortBreakDuration)) min")
                            Spacer()
                            Text("\(Int(shortBreakDuration))")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Slider(value: $shortBreakDuration, in: 1...30, step: 1) {
                            Text("Short Break Duration")
                        }
                    }
                    
                    VStack {
                        HStack {
                            Text("Long Break: \(Int(longBreakDuration)) min")
                            Spacer()
                            Text("\(Int(longBreakDuration))")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Slider(value: $longBreakDuration, in: 1...60, step: 1) {
                            Text("Long Break Duration")
                        }
                    }
                }
                
                Section(header: Text("Session Structure")) {
                    VStack {
                        HStack {
                            Text("Cycles before long break: \(Int(cyclesBeforeLongBreak))")
                            Spacer()
                            Text("\(Int(cyclesBeforeLongBreak))")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Slider(value: $cyclesBeforeLongBreak, in: 1...10, step: 1) {
                            Text("Cycles before long break")
                        }
                    }
                    
                    VStack {
                        HStack {
                            Text("Delay between timers: \(Int(delayBetweenTimers)) sec")
                            Spacer()
                            Text("\(Int(delayBetweenTimers))")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Slider(value: $delayBetweenTimers, in: 0...120, step: 5) {
                            Text("Delay between timers")
                        }
                    }
                }
                
                Section(header: Text("Interaction")) {
                    Toggle("Use Voice Interaction", isOn: $useVoiceInteraction)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if useVoiceInteraction {
                        Text("At the start of each session, you'll be prompted to talk with AI about what you're working on.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("You'll be asked to type what you're working on at the start of each session.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                }
            }
            .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
            .navigationTitle("Settings")
            .overlay(
                Group {
                    if showSavedBanner {
                        VStack {
                            Spacer()
                            
                            Text("Settings Saved")
                                .font(.headline)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.bottom, 20)
                                .transition(.move(edge: .bottom))
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showSavedBanner = false
                                        }
                                    }
                                }
                        }
                        .animation(.easeInOut, value: showSavedBanner)
                    }
                }
            )
        }
    }
    
    private func saveSettings() {
        let newSettings = TimerSettings(
            workDuration: Int(workDuration),
            shortBreakDuration: Int(shortBreakDuration),
            longBreakDuration: Int(longBreakDuration),
            cyclesBeforeLongBreak: Int(cyclesBeforeLongBreak),
            delayBetweenTimers: Int(delayBetweenTimers),
            useVoiceInteraction: useVoiceInteraction
        )
        
        timerManager.updateSettings(newSettings)
        
        withAnimation {
            showSavedBanner = true
        }
    }
    
    private func resetToDefaults() {
        let defaultSettings = TimerSettings.default
        workDuration = Double(defaultSettings.workDuration)
        shortBreakDuration = Double(defaultSettings.shortBreakDuration)
        longBreakDuration = Double(defaultSettings.longBreakDuration)
        cyclesBeforeLongBreak = Double(defaultSettings.cyclesBeforeLongBreak)
        delayBetweenTimers = Double(defaultSettings.delayBetweenTimers)
        useVoiceInteraction = defaultSettings.useVoiceInteraction
        
        timerManager.updateSettings(defaultSettings)
        
        withAnimation {
            showSavedBanner = true
        }
    }
} 
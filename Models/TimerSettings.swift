import Foundation

struct TimerSettings: Codable {
    var workDuration: Int // in minutes
    var shortBreakDuration: Int // in minutes
    var longBreakDuration: Int // in minutes
    var cyclesBeforeLongBreak: Int
    var delayBetweenTimers: Int // in seconds
    
    static let `default` = TimerSettings(
        workDuration: 25,
        shortBreakDuration: 5,
        longBreakDuration: 15,
        cyclesBeforeLongBreak: 4,
        delayBetweenTimers: 30
    )
    
    static func load() -> TimerSettings {
        guard let data = UserDefaults.standard.data(forKey: "timerSettings"),
              let settings = try? JSONDecoder().decode(TimerSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "timerSettings")
        }
    }
} 
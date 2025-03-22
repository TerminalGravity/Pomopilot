import Foundation

// Enum to represent different timer types
enum TimerType: String, Codable {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case delay = "Delay"
}

// A model representing a single work period
struct WorkPeriod: Identifiable, Codable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var input: String = ""
    
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
}

// The overall session that contains multiple work periods
struct Session: Identifiable, Codable {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var workPeriods: [WorkPeriod] = []
    var aiReport: String = ""
    
    var isCompleted: Bool {
        return endTime != nil
    }
    
    var totalWorkDuration: TimeInterval {
        return workPeriods.reduce(0) { $0 + $1.duration }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
} 
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
    var breakFeedback: String = ""
    var aiResponse: String = ""
    
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
    var googleDocsLink: String = ""
    
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
    
    // Generate a formatted string for Google Docs export
    func generateFormattedReport() -> String {
        var report = "# POMOPILOT SESSION REPORT\n\n"
        report += "**Date:** \(formattedDate)\n"
        report += "**Total Work Duration:** \(formatDuration(totalWorkDuration))\n\n"
        
        report += "## Work Periods\n\n"
        for (index, period) in workPeriods.enumerated() {
            report += "### Period \(index + 1) - \(formatDuration(period.duration))\n\n"
            report += "**Accomplishments:**\n\(period.input)\n\n"
            
            if !period.breakFeedback.isEmpty {
                report += "**Break Feedback:**\n\(period.breakFeedback)\n\n"
            }
            
            if !period.aiResponse.isEmpty {
                report += "**AI Insights:**\n\(period.aiResponse)\n\n"
            }
        }
        
        if !aiReport.isEmpty {
            report += "## Productivity Report\n\n"
            report += aiReport
        }
        
        return report
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
} 
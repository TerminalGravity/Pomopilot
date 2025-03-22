import Foundation

class SessionManager: ObservableObject {
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []
    
    init() {
        loadSessions()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WorkPeriodCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let workPeriod = notification.object as? WorkPeriod {
                self?.addWorkPeriodToCurrentSession(workPeriod)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SessionCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.completeCurrentSession()
        }
    }
    
    func startNewSession() {
        currentSession = Session(startTime: Date())
        saveCurrentSession()
    }
    
    func addWorkPeriodToCurrentSession(_ workPeriod: WorkPeriod) {
        guard var session = currentSession else { return }
        session.workPeriods.append(workPeriod)
        currentSession = session
        saveCurrentSession()
    }
    
    func completeCurrentSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        
        // Generate AI report
        session.aiReport = generateAIReport(for: session)
        
        // Update current session
        currentSession = session
        
        // Update sessions list
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        
        saveSessions()
    }
    
    func generateAIReport(for session: Session) -> String {
        // In a real app, this would call an AI service
        // For now, we'll simulate it with a rule-based approach
        
        let workPeriods = session.workPeriods
        let totalWorkTime = Int(session.totalWorkDuration / 60)
        
        // Extract activities from inputs
        let activities = workPeriods.compactMap { $0.input.isEmpty ? nil : $0.input }
        
        if activities.isEmpty {
            return "You completed a session with \(workPeriods.count) work periods, totaling \(totalWorkTime) minutes of focused work time. No activities were recorded."
        }
        
        // Create the report
        var report = "Session Summary:\n"
        report += "- You completed \(workPeriods.count) work periods\n"
        report += "- Total work time: \(totalWorkTime) minutes\n\n"
        
        report += "Activities:\n"
        for (index, activity) in activities.enumerated() {
            report += "- Period \(index + 1): \(activity)\n"
        }
        
        // Add a simple insight
        if activities.count > 1 {
            report += "\nInsight: You were most productive during your "
            
            let longestInput = activities.max(by: { $0.count < $1.count }) ?? ""
            let periodIndex = workPeriods.firstIndex { $0.input == longestInput } ?? 0
            
            report += "period \(periodIndex + 1) where you wrote the most detailed notes."
        }
        
        return report
    }
    
    private func saveCurrentSession() {
        guard let session = currentSession else { return }
        
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        
        saveSessions()
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "savedSessions")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "savedSessions"),
              let savedSessions = try? JSONDecoder().decode([Session].self, from: data) else {
            return
        }
        sessions = savedSessions
        
        // Find any active session
        currentSession = sessions.first(where: { !$0.isCompleted })
    }
    
    func deleteSession(at indexSet: IndexSet) {
        sessions.remove(atOffsets: indexSet)
        saveSessions()
    }
} 
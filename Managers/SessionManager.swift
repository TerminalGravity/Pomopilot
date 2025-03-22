import Foundation

class SessionManager: ObservableObject {
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []
    @Published var isExporting = false
    @Published var exportError: String?
    @Published var exportSuccess = false
    
    private let geminiManager = GeminiAPIManager()
    
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
        
        // New observer for break feedback
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BreakFeedbackReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let feedbackInfo = notification.object as? [String: String],
               let workPeriodId = feedbackInfo["workPeriodId"],
               let feedback = feedbackInfo["feedback"],
               let aiResponse = feedbackInfo["aiResponse"] {
                self?.addBreakFeedback(workPeriodId: workPeriodId, feedback: feedback, aiResponse: aiResponse)
            }
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
    
    func addBreakFeedback(workPeriodId: String, feedback: String, aiResponse: String) {
        guard var session = currentSession else { return }
        
        if let index = session.workPeriods.firstIndex(where: { $0.id.uuidString == workPeriodId }) {
            var workPeriod = session.workPeriods[index]
            workPeriod.breakFeedback = feedback
            workPeriod.aiResponse = aiResponse
            session.workPeriods[index] = workPeriod
            currentSession = session
            saveCurrentSession()
        }
    }
    
    func completeCurrentSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        
        // Generate AI report
        generateAIReport(for: session) { [weak self] report in
            guard let self = self else { return }
            
            session.aiReport = report
            
            // Update current session
            self.currentSession = session
            
            // Update sessions list
            if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[index] = session
            } else {
                self.sessions.append(session)
            }
            
            self.saveSessions()
        }
    }
    
    func generateAIReport(for session: Session, completion: @escaping (String) -> Void) {
        // Use Gemini API for report generation
        geminiManager.generateProductivityReport(workPeriods: session.workPeriods) { report in
            completion(report)
        }
    }
    
    func exportToGoogleDocs(session: Session) {
        isExporting = true
        exportError = nil
        exportSuccess = false
        
        // In a real app, you would integrate with Google Docs API here
        // For this example, we'll simulate the export with a delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Simulate success
            self.isExporting = false
            self.exportSuccess = true
            
            // Add a fake Google Docs link to the session
            if var updatedSession = self.sessions.first(where: { $0.id == session.id }) {
                updatedSession.googleDocsLink = "https://docs.google.com/document/d/\(UUID().uuidString)"
                
                if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                    self.sessions[index] = updatedSession
                    self.saveSessions()
                }
            }
            
            // Reset success state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.exportSuccess = false
            }
        }
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
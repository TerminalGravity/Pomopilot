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
        DispatchQueue.main.async {
            self.currentSession = Session(startTime: Date())
            self.saveCurrentSession()
        }
    }
    
    func addWorkPeriodToCurrentSession(_ workPeriod: WorkPeriod) {
        guard var session = currentSession else { return }
        
        DispatchQueue.main.async {
            session.workPeriods.append(workPeriod)
            self.currentSession = session
            self.saveCurrentSession()
        }
    }
    
    func addBreakFeedback(workPeriodId: String, feedback: String, aiResponse: String) {
        guard var session = currentSession else { return }
        
        if let index = session.workPeriods.firstIndex(where: { $0.id.uuidString == workPeriodId }) {
            var workPeriod = session.workPeriods[index]
            workPeriod.breakFeedback = feedback
            workPeriod.aiResponse = aiResponse
            
            DispatchQueue.main.async {
                session.workPeriods[index] = workPeriod
                self.currentSession = session
                self.saveCurrentSession()
            }
        }
    }
    
    func completeCurrentSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        
        // Generate AI report
        generateAIReport(for: session) { [weak self] report in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
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
    }
    
    func generateAIReport(for session: Session, completion: @escaping (String) -> Void) {
        // Use Gemini API for report generation
        geminiManager.generateProductivityReport(workPeriods: session.workPeriods) { report in
            completion(report)
        }
    }
    
    // MARK: - Persistence
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "savedSessions") {
            if let decoded = try? JSONDecoder().decode([Session].self, from: data) {
                DispatchQueue.main.async {
                    self.sessions = decoded
                    
                    // Find any active session
                    self.currentSession = self.sessions.first(where: { $0.endTime == nil })
                }
            }
        }
    }
    
    private func saveCurrentSession() {
        guard let currentSession = currentSession else { return }
        
        // Update the session in the sessions array if it exists, otherwise add it
        if let index = sessions.firstIndex(where: { $0.id == currentSession.id }) {
            DispatchQueue.main.async {
                self.sessions[index] = currentSession
                self.saveSessions()
            }
        } else {
            DispatchQueue.main.async {
                self.sessions.append(currentSession)
                self.saveSessions()
            }
        }
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }
    }
    
    // MARK: - List Management
    
    func deleteSession(at indexSet: IndexSet) {
        DispatchQueue.main.async {
            // If the deleted session is the current session, clear it
            for index in indexSet {
                if index < self.sessions.count {
                    let sessionToDelete = self.sessions[index]
                    if sessionToDelete.id == self.currentSession?.id {
                        self.currentSession = nil
                    }
                }
            }
            
            // Remove the sessions
            self.sessions.remove(atOffsets: indexSet)
            self.saveSessions()
        }
    }
    
    // MARK: - Export Functionality
    
    func exportToGoogleDocs(session: Session) {
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportError = nil
            self.exportSuccess = false
        }
        
        // In a real app, you would integrate with Google Docs API here
        // For this example, we'll simulate the export with a delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Simulate success
            DispatchQueue.main.async {
                // Add a fake Google Docs link to the session
                if var updatedSession = self.sessions.first(where: { $0.id == session.id }) {
                    updatedSession.googleDocsLink = "https://docs.google.com/document/d/\(UUID().uuidString)"
                    
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        self.sessions[index] = updatedSession
                        self.saveSessions()
                    }
                }
                
                self.isExporting = false
                self.exportSuccess = true
                
                // Reset success state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.exportSuccess = false
                }
            }
        }
    }
    
    func exportSessions() {
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportError = nil
            self.exportSuccess = false
        }
        
        // Create a formatted JSON file with sessions data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "pomopilot_sessions_\(dateFormatter.string(from: Date())).json"
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(sessions) else {
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportError = "Failed to encode session data"
            }
            return
        }
        
        // Get the Documents directory URL
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportError = "Couldn't access documents directory"
            }
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Write to the file
        do {
            try jsonData.write(to: fileURL)
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportSuccess = true
            }
        } catch {
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportError = "Failed to write file: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteAllSessions() {
        DispatchQueue.main.async {
            self.sessions = []
            self.currentSession = nil
            UserDefaults.standard.removeObject(forKey: "savedSessions")
        }
    }
} 
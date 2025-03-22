import Foundation
import UserNotifications

class TimerManager: ObservableObject {
    @Published var settings = TimerSettings.load()
    @Published var currentTimerType: TimerType = .work
    @Published var timeRemaining: Int = 0
    @Published var isRunning = false
    @Published var currentCycle = 1
    @Published var shouldShowInputPrompt = false
    @Published var currentInput = ""
    
    // New property for session start prompt
    @Published var shouldShowSessionStartPrompt = false
    @Published var sessionStartInput = ""
    
    // New property for voice interaction
    @Published var shouldShowVoiceInteraction = false
    
    // AI-related properties
    @Published var aiMessage: String = ""
    @Published var showAIReminder: Bool = false
    @Published var showAIBreakEngagement: Bool = false
    @Published var userBreakFeedback: String = ""
    @Published var showBreakFeedbackPrompt: Bool = false
    @Published var aiBreakResponse: String = ""
    @Published var showAIBreakResponse: Bool = false
    
    // Selected voice for Gemini Live API
    @Published var selectedVoice: GeminiAPIManager.GeminiVoice = .kore
    
    private var timer: Timer?
    private var startDate: Date?
    private var workPeriod: WorkPeriod?
    private let geminiManager = GeminiAPIManager()
    private var reminderShown = false
    private var breakEngagementTimer: Timer?
    private var timerQueue = DispatchQueue(label: "com.pomopilot.timerQueue")
    private var voiceConversationText = ""
    
    var progress: Double {
        let totalTime = getTotalTimeForCurrentTimer()
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }
    
    // Add a method to access the GeminiAPIManager
    func getGeminiManager() -> GeminiAPIManager {
        return geminiManager
    }
    
    init() {
        resetTimer()
        requestNotificationPermission()
        
        // Load selected voice from UserDefaults if available
        if let savedVoice = UserDefaults.standard.string(forKey: "selectedGeminiVoice"),
           let voice = GeminiAPIManager.GeminiVoice(rawValue: savedVoice) {
            selectedVoice = voice
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func resetTimer() {
        timeRemaining = getTotalTimeForCurrentTimer()
        reminderShown = false
    }
    
    func getTotalTimeForCurrentTimer() -> Int {
        switch currentTimerType {
        case .work:
            return settings.workDuration * 60
        case .shortBreak:
            return settings.shortBreakDuration * 60
        case .longBreak:
            return settings.longBreakDuration * 60
        case .delay:
            return settings.delayBetweenTimers
        }
    }
    
    // Begin timer after getting voice conversation
    func startTimerWithConversation(_ conversation: String) {
        DispatchQueue.main.async {
            self.voiceConversationText = conversation
            self.shouldShowVoiceInteraction = false
            self.startTimerInternal()
        }
    }
    
    // Update the selected voice
    func updateSelectedVoice(_ voice: GeminiAPIManager.GeminiVoice) {
        DispatchQueue.main.async {
            self.selectedVoice = voice
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(voice.rawValue, forKey: "selectedGeminiVoice")
        }
    }
    
    // Begin timer after getting session start input
    func startTimerWithInput(_ taskDescription: String) {
        DispatchQueue.main.async {
            self.sessionStartInput = taskDescription
            self.shouldShowSessionStartPrompt = false
            self.startTimerInternal()
        }
    }
    
    // Method to prompt for session start input
    func promptForSessionStart() {
        DispatchQueue.main.async {
            self.sessionStartInput = ""
            self.shouldShowSessionStartPrompt = true
        }
    }
    
    // Method to show voice interaction
    func promptForVoiceInteraction() {
        DispatchQueue.main.async {
            self.voiceConversationText = ""
            self.shouldShowVoiceInteraction = true
        }
    }
    
    // Method to start the timer
    func start() {
        if !isRunning {
            // If this is a work period and we're at the beginning of a cycle, prompt based on user preference
            if currentTimerType == .work && currentCycle == 1 {
                // Check for user preference: voice or text input
                // For this implementation, let's default to voice
                if settings.useVoiceInteraction {
                    promptForVoiceInteraction()
                } else {
                    promptForSessionStart()
                }
            } else {
                startTimerInternal()
            }
        }
    }
    
    // Internal timer start method that actually starts the timer
    private func startTimerInternal() {
        isRunning = true
        startDate = Date()
        
        if currentTimerType == .work {
            // Create work period with the task description and/or conversation
            var newWorkPeriod = WorkPeriod(startTime: Date())
            
            // Add the task description if this is the first period in a new session
            if currentCycle == 1 {
                if !sessionStartInput.isEmpty {
                    newWorkPeriod.taskDescription = sessionStartInput
                }
                
                if !voiceConversationText.isEmpty {
                    newWorkPeriod.voiceConversation = voiceConversationText
                    
                    // Extract a task description from conversation if none provided
                    if newWorkPeriod.taskDescription.isEmpty {
                        newWorkPeriod.taskDescription = extractTaskFromConversation(voiceConversationText)
                    }
                    
                    // Add the selected voice information
                    newWorkPeriod.voiceUsed = selectedVoice.rawValue
                }
            }
            
            workPeriod = newWorkPeriod
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timerQueue.async {
                if self.timeRemaining > 0 {
                    DispatchQueue.main.async {
                        self.timeRemaining -= 1
                    }
                    
                    // Check for 2-minute reminder if in work mode
                    if self.currentTimerType == .work && self.timeRemaining == 120 && !self.reminderShown {
                        self.showTwoMinuteReminder()
                    }
                    
                    // Schedule break engagement if in break mode
                    if (self.currentTimerType == .shortBreak || self.currentTimerType == .longBreak) && 
                       self.timeRemaining == self.getTotalTimeForCurrentTimer() - 30 {
                        self.scheduleBreakEngagement()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.timerComplete()
                    }
                }
            }
        }
    }
    
    // Extract a task description from the conversation
    private func extractTaskFromConversation(_ conversation: String) -> String {
        return geminiManager.extractTaskFromConversation(conversation)
    }
    
    func pause() {
        timer?.invalidate()
        breakEngagementTimer?.invalidate()
        isRunning = false
    }
    
    func showTwoMinuteReminder() {
        reminderShown = true
        
        geminiManager.getEndOfSessionReminder { [weak self] message in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.aiMessage = message
                self.showAIReminder = true
                self.sendReminderNotification(message: message)
            }
        }
    }
    
    func scheduleBreakEngagement() {
        // Schedule engagement at random intervals during the break
        let breakDuration = self.currentTimerType == .shortBreak ? 
            settings.shortBreakDuration : settings.longBreakDuration
        
        // Schedule the first engagement after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isRunning, 
                  (self.currentTimerType == .shortBreak || self.currentTimerType == .longBreak) else { 
                return 
            }
            self.showBreakEngagement()
        }
    }
    
    func showBreakEngagement() {
        geminiManager.getBreakEngagement(timeRemaining: timeRemaining) { [weak self] message in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.aiMessage = message
                self.showAIBreakEngagement = true
                self.showBreakFeedbackPrompt = true
            }
        }
    }
    
    func submitBreakFeedback() {
        if userBreakFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async {
                self.showBreakFeedbackPrompt = false
            }
            return
        }
        
        let feedback = userBreakFeedback // Capture current value
        
        geminiManager.processBreakFeedback(feedback: feedback) { [weak self] response in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.aiBreakResponse = response
                self.showBreakFeedbackPrompt = false
                self.showAIBreakResponse = true
                
                // Store the feedback for the work log
                if let wp = self.workPeriod {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("BreakFeedbackReceived"), 
                        object: ["workPeriodId": wp.id.uuidString, "feedback": feedback, "aiResponse": response]
                    )
                }
                
                // Clear for next time
                self.userBreakFeedback = ""
            }
        }
    }
    
    func dismissAIInteraction() {
        DispatchQueue.main.async {
            self.showAIReminder = false
            self.showAIBreakEngagement = false
            self.showBreakFeedbackPrompt = false
            self.showAIBreakResponse = false
        }
    }
    
    // Method to show voice interaction during a running timer
    func showVoiceInteractionDuringTimer() {
        DispatchQueue.main.async {
            if self.isRunning {
                self.shouldShowVoiceInteraction = true
            }
        }
    }
    
    func timerComplete() {
        timer?.invalidate()
        breakEngagementTimer?.invalidate()
        isRunning = false
        
        // Send notification
        sendTimerCompletionNotification()
        
        // If work timer completed, show input prompt
        if currentTimerType == .work {
            if let wp = workPeriod {
                var updatedWorkPeriod = wp
                updatedWorkPeriod.endTime = Date()
                workPeriod = updatedWorkPeriod
                
                DispatchQueue.main.async {
                    self.shouldShowInputPrompt = true
                }
            }
        } else {
            moveToNextTimer()
        }
    }
    
    func submitInput() {
        if var wp = workPeriod {
            wp.input = currentInput
            NotificationCenter.default.post(name: NSNotification.Name("WorkPeriodCompleted"), object: wp)
            
            DispatchQueue.main.async {
                self.currentInput = ""
                self.shouldShowInputPrompt = false
            }
            
            workPeriod = nil
            moveToNextTimer()
        }
    }
    
    func moveToNextTimer() {
        DispatchQueue.main.async {
            switch self.currentTimerType {
            case .work:
                self.currentTimerType = .delay
                self.timeRemaining = self.settings.delayBetweenTimers
                self.start()
                
            case .delay:
                let isLongBreakDue = self.currentCycle % self.settings.cyclesBeforeLongBreak == 0
                self.currentTimerType = isLongBreakDue ? .longBreak : .shortBreak
                self.resetTimer()
                self.start()
                
            case .shortBreak, .longBreak:
                if self.currentTimerType == .longBreak {
                    // One full cycle completed
                    self.currentCycle = 1
                    NotificationCenter.default.post(name: NSNotification.Name("SessionCompleted"), object: nil)
                } else {
                    self.currentCycle += 1
                }
                
                self.currentTimerType = .delay
                self.timeRemaining = self.settings.delayBetweenTimers
                self.start()
            }
        }
    }
    
    func sendReminderNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to wrap up!"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendTimerCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "\(currentTimerType.rawValue) Complete"
        content.body = currentTimerType == .work ? 
            "Time to take a break! What did you accomplish?" : 
            "Break complete. Get ready for your next work session."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func stop() {
        timer?.invalidate()
        breakEngagementTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.resetTimer()
            self.currentCycle = 1
            self.currentTimerType = .work
            self.shouldShowInputPrompt = false
            self.currentInput = ""
            self.dismissAIInteraction()
        }
        
        workPeriod = nil
    }
    
    func updateSettings(_ newSettings: TimerSettings) {
        DispatchQueue.main.async {
            self.settings = newSettings
            self.settings.save()
            self.resetTimer()
        }
    }
} 
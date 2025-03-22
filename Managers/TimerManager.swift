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
    
    // AI-related properties
    @Published var aiMessage: String = ""
    @Published var showAIReminder: Bool = false
    @Published var showAIBreakEngagement: Bool = false
    @Published var userBreakFeedback: String = ""
    @Published var showBreakFeedbackPrompt: Bool = false
    @Published var aiBreakResponse: String = ""
    @Published var showAIBreakResponse: Bool = false
    
    private var timer: Timer?
    private var startDate: Date?
    private var workPeriod: WorkPeriod?
    private let geminiManager = GeminiAPIManager()
    private var reminderShown = false
    private var breakEngagementTimer: Timer?
    
    var progress: Double {
        let totalTime = getTotalTimeForCurrentTimer()
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }
    
    init() {
        resetTimer()
        requestNotificationPermission()
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
    
    func start() {
        if !isRunning {
            isRunning = true
            startDate = Date()
            
            if currentTimerType == .work {
                workPeriod = WorkPeriod(startTime: Date())
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    
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
                    self.timerComplete()
                }
            }
        }
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
            showBreakFeedbackPrompt = false
            return
        }
        
        geminiManager.processBreakFeedback(feedback: userBreakFeedback) { [weak self] response in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.aiBreakResponse = response
                self.showBreakFeedbackPrompt = false
                self.showAIBreakResponse = true
                
                // Store the feedback for the work log
                if let wp = self.workPeriod {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("BreakFeedbackReceived"), 
                        object: ["workPeriodId": wp.id.uuidString, "feedback": self.userBreakFeedback, "aiResponse": response]
                    )
                }
                
                // Clear for next time
                self.userBreakFeedback = ""
            }
        }
    }
    
    func dismissAIInteraction() {
        showAIReminder = false
        showAIBreakEngagement = false
        showBreakFeedbackPrompt = false
        showAIBreakResponse = false
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
                shouldShowInputPrompt = true
            }
        } else {
            moveToNextTimer()
        }
    }
    
    func submitInput() {
        if var wp = workPeriod {
            wp.input = currentInput
            NotificationCenter.default.post(name: NSNotification.Name("WorkPeriodCompleted"), object: wp)
            currentInput = ""
            shouldShowInputPrompt = false
            workPeriod = nil
            moveToNextTimer()
        }
    }
    
    func moveToNextTimer() {
        switch currentTimerType {
        case .work:
            currentTimerType = .delay
            timeRemaining = settings.delayBetweenTimers
            start()
            
        case .delay:
            let isLongBreakDue = currentCycle % settings.cyclesBeforeLongBreak == 0
            currentTimerType = isLongBreakDue ? .longBreak : .shortBreak
            resetTimer()
            start()
            
        case .shortBreak, .longBreak:
            if currentTimerType == .longBreak {
                // One full cycle completed
                currentCycle = 1
                NotificationCenter.default.post(name: NSNotification.Name("SessionCompleted"), object: nil)
            } else {
                currentCycle += 1
            }
            
            currentTimerType = .delay
            timeRemaining = settings.delayBetweenTimers
            start()
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
        isRunning = false
        resetTimer()
        currentCycle = 1
        currentTimerType = .work
        workPeriod = nil
        shouldShowInputPrompt = false
        currentInput = ""
        dismissAIInteraction()
    }
    
    func updateSettings(_ newSettings: TimerSettings) {
        settings = newSettings
        settings.save()
        resetTimer()
    }
} 
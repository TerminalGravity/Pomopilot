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
    
    private var timer: Timer?
    private var startDate: Date?
    private var workPeriod: WorkPeriod?
    
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
                } else {
                    self.timerComplete()
                }
            }
        }
    }
    
    func pause() {
        timer?.invalidate()
        isRunning = false
    }
    
    func timerComplete() {
        timer?.invalidate()
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
        isRunning = false
        resetTimer()
        currentCycle = 1
        currentTimerType = .work
        workPeriod = nil
        shouldShowInputPrompt = false
        currentInput = ""
    }
    
    func updateSettings(_ newSettings: TimerSettings) {
        settings = newSettings
        settings.save()
        resetTimer()
    }
} 
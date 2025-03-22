import Foundation
import Combine
import GoogleGenerativeAI

class GeminiAPIManager: ObservableObject {
    // API configuration
    private(set) var apiKey: String
    private let apiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    
    // Published properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Voice support - Live API voices
    enum GeminiVoice: String, CaseIterable, Identifiable {
        case aoede = "Aoede"
        case charon = "Charon"
        case fenrir = "Fenrir"
        case kore = "Kore"
        case puck = "Puck"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .aoede: return "Aoede - Female, gentle tone"
            case .charon: return "Charon - Male, deep voice"
            case .fenrir: return "Fenrir - Male, strong accent"
            case .kore: return "Kore - Female, professional tone"
            case .puck: return "Puck - Male, playful tone"
            }
        }
        
        var voiceConfig: [String: Any] {
            return [
                "voiceConfig": [
                    "prebuiltVoiceConfig": [
                        "voiceName": self.rawValue
                    ]
                ]
            ]
        }
    }
    
    init() {
        // Load API key from environment or secure storage
        if let apiKeyFromEnvironment = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            self.apiKey = apiKeyFromEnvironment
        } else if let apiKeyFromBundle = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String {
            self.apiKey = apiKeyFromBundle
        } else {
            // For development only - never ship with hardcoded keys
            #if DEBUG
            // API key from Google AI Studio (https://aistudio.google.com/app/apikey)
            self.apiKey = "AIzaSyBqP70sf6WHU61M3lDm5Qs2zgTcshuf4o8"
            #else
            self.apiKey = "AIzaSyBqP70sf6WHU61M3lDm5Qs2zgTcshuf4o8"
            #endif
        }
    }
    
    // Get available voice options from Gemini Live API
    func getAvailableVoices() -> [GeminiVoice] {
        return GeminiVoice.allCases
    }
    
    // Create a GenerativeModel with the Live API configuration and selected voice
    func createLiveModel(voiceName: GeminiVoice) -> GenerativeModel {
        // Use the correct enum values for the HarmCategory
        let safetySettings = [
            SafetySetting(harmCategory: .harassment, threshold: .blockNone),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockNone),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
        ]
        
        let config = GenerationConfig(
            temperature: 0.7,
            topP: 0.95,
            topK: 64,
            maxOutputTokens: 2048
        )
        
        // Voice configuration for Live API
        let systemInstruction = """
        You are a friendly AI assistant named PomoPilot that helps people stay focused and productive.
        You should engage in natural conversation and help users set up their Pomodoro sessions.
        Ask them about what they're working on and be encouraging.
        Keep responses short and helpful, around 1-2 sentences.
        """
        
        return GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: config,
            safetySettings: safetySettings,
            systemInstruction: systemInstruction
        )
    }
    
    // Process conversation input for voice interaction feature
    func processStartConversation(input: String, completion: @escaping (String) -> Void) {
        let prompt: String
        
        // Check for specific intents
        if input.lowercased().contains("what") && 
           (input.lowercased().contains("work on") || input.lowercased().contains("do today")) {
            prompt = "The user is asking about what to work on. Respond helpfully and ask what specific task they want to focus on for their Pomodoro session."
        } else if containsReadyTrigger(input) {
            prompt = "The user seems ready to start their Pomodoro session. Ask them if they're ready to begin the timer."
        } else if input.count < 10 {
            prompt = "The user provided a short response: '\(input)'. Based on this, ask them to elaborate on what they want to accomplish during their Pomodoro session today."
        } else {
            prompt = "User is starting a Pomodoro session and said: '\(input)'. Respond conversationally and help them focus on their task. If they've shared what they're working on, acknowledge it and ask if they're ready to start the timer."
        }
        
        generateResponse(prompt: prompt, completion: completion)
    }
    
    private func containsReadyTrigger(_ input: String) -> Bool {
        let readyPhrases = ["ready", "let's go", "start", "begin", "yes", "sure", "okay", "ok"]
        let lowerInput = input.lowercased()
        return readyPhrases.contains { lowerInput.contains($0) }
    }
    
    // Request AI reminder for end of work session
    func getEndOfSessionReminder(completion: @escaping (String) -> Void) {
        let prompt = "Generate a short, encouraging reminder that a work session is ending in 2 minutes. The message should remind the user to wrap up what they're doing and prepare for a break."
        generateResponse(prompt: prompt, completion: completion)
    }
    
    // Request AI engagement during break
    func getBreakEngagement(timeRemaining: Int, completion: @escaping (String) -> Void) {
        let minutes = timeRemaining / 60
        let prompt = "Generate a short, thoughtful message for someone on a \(minutes)-minute break from work. Ask them a reflective question about their work quality, break experience, or plans for their next session."
        generateResponse(prompt: prompt, completion: completion)
    }
    
    // Generate productivity report based on session data
    func generateProductivityReport(workPeriods: [WorkPeriod], completion: @escaping (String) -> Void) {
        var prompt = "Generate a concise productivity report based on these work sessions:\n"
        
        for (index, period) in workPeriods.enumerated() {
            let duration = period.endTime?.timeIntervalSince(period.startTime) ?? 0
            let minutes = Int(duration / 60)
            
            prompt += "Session \(index + 1) (\(minutes) minutes):\n"
            
            if !period.taskDescription.isEmpty {
                prompt += "Working on: \(period.taskDescription)\n"
            }
            
            if !period.voiceConversation.isEmpty {
                prompt += "Initial conversation: \(period.voiceConversation)\n"
            }
            
            prompt += "Accomplishments: \(period.input)\n\n"
        }
        
        prompt += "\nProvide actionable insights about productivity patterns, focused work time quality, and suggestions for improvement."
        
        generateResponse(prompt: prompt, completion: completion)
    }
    
    // Process user feedback during break
    func processBreakFeedback(feedback: String, completion: @escaping (String) -> Void) {
        let prompt = "Based on this break-time feedback: '\(feedback)', generate a thoughtful, personalized response that acknowledges the feedback and provides a relevant question or suggestion to improve the next work session."
        generateResponse(prompt: prompt, completion: completion)
    }
    
    // Core method to send requests to Gemini API
    private func generateResponse(prompt: String, completion: @escaping (String) -> Void) {
        // For development/testing without API key, return mock responses
        #if DEBUG
        if apiKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(self.getMockResponse(for: prompt))
            }
            return
        }
        #endif
        
        guard let url = URL(string: "\(apiBaseURL)?key=\(apiKey)") else {
            self.errorMessage = "Invalid URL"
            completion("Sorry, I couldn't process your request.")
            return
        }
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            self.errorMessage = "Failed to serialize request"
            completion("Sorry, I couldn't process your request.")
            return
        }
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Update state on main thread to avoid threading issues
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Perform the request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                // Handle errors
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion("Sorry, I encountered an error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    completion("Sorry, I didn't receive any response.")
                    return
                }
                
                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        completion(text)
                    } else {
                        // Check for error message in the response
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            self.errorMessage = "API Error: \(message)"
                            completion("Sorry, there was an API error: \(message)")
                        } else {
                            self.errorMessage = "Invalid response format"
                            completion("Sorry, I couldn't understand the response.")
                        }
                    }
                } catch {
                    self.errorMessage = "JSON parsing error: \(error.localizedDescription)"
                    completion("Sorry, I couldn't process the response.")
                }
            }
        }.resume()
    }
    
    // Mock responses for development/testing
    private func getMockResponse(for prompt: String) -> String {
        if prompt.contains("ending in 2 minutes") {
            return "You have 2 minutes remaining in this session. Start wrapping up your current task and prepare for your break."
        } else if prompt.contains("break from work") {
            return "How's your break going? Take a moment to reflect: what aspect of your last work session felt most productive to you?"
        } else if prompt.contains("productivity report") {
            return "Productivity Report: You had 3 focused work sessions with good output. Your second session appears to have been your most productive. Consider scheduling challenging tasks during that time of day for peak performance."
        } else if prompt.contains("break-time feedback") {
            return "Thanks for sharing that. It sounds like you found some good momentum in your last session. For your next session, consider setting a specific mini-goal to maintain that focus. What would be a satisfying accomplishment to reach in the next 25 minutes?"
        } else if prompt.contains("start") || prompt.contains("ready to begin") {
            return "Great! Are you ready to start the timer and begin your focused work session?"
        } else if prompt.contains("Pomodoro session") {
            return "I see you're planning to work on something. Could you tell me more about what you'll be focusing on during this Pomodoro session?"
        }
        return "I'm here to help you stay productive. What would you like to focus on during your Pomodoro session today?"
    }
    
    // Method to extract task description from conversation
    func extractTaskFromConversation(_ conversation: String) -> String {
        // If conversation is empty, return empty string
        if conversation.isEmpty {
            return ""
        }
        
        // Define keywords that might indicate a task description
        let taskIndicators = ["work on", "working on", "focus on", "focusing on", "task is", "project is"]
        
        // Split conversation into sentences
        let sentences = conversation.components(separatedBy: [".", "!", "?"])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // First look for sentences with task indicators
        for sentence in sentences {
            let lowercaseSentence = sentence.lowercased()
            for indicator in taskIndicators {
                if lowercaseSentence.contains(indicator) {
                    // Extract text after the indicator
                    if let range = lowercaseSentence.range(of: indicator) {
                        let startIndex = lowercaseSentence.index(range.upperBound, offsetBy: 0)
                        let taskDescription = sentence[startIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !taskDescription.isEmpty {
                            return taskDescription
                        }
                    }
                }
            }
        }
        
        // If no clear indicator, use the first complete sentence as a fallback
        if !sentences.isEmpty {
            return sentences[0]
        }
        
        // Last resort: just return the whole conversation if it's short
        if conversation.count < 100 {
            return conversation
        }
        
        return ""
    }
}

// Voice option structure
struct VoiceOption: Identifiable, Hashable {
    var id: String
    var name: String
} 
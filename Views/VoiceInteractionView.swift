import SwiftUI
import AVFoundation
import GoogleGenerativeAI
import Speech

struct VoiceInteractionView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var animateCircle = false
    @State private var circleScale: CGFloat = 1.0
    @State private var messages: [ChatMessage] = []
    @State private var isListening = false
    @State private var isSpeaking = false
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var transcript = ""
    @State private var showVoiceSettings = false
    @State private var selectedVoice: GeminiAPIManager.GeminiVoice = .kore
    @State private var showTextMessages = false
    @State private var listeningTimeout: Timer?
    @State private var voiceActivityDetected = false
    @State private var currentPersona: GeminiPersona = .assistant
    
    // Gemini model
    @State private var geminiModel: GenerativeModel?
    @State private var chatSession: Chat?
    @State private var isConnected = false
    @State private var isProcessingAudio = false
    
    var body: some View {
        ZStack {
            // Main content: Voice interaction bubble
            VStack {
                Spacer()
                
                // Voice indicator with activity detection
                ZStack {
                    // Connection status and background circle
                    Circle()
                        .fill(isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    // Outer pulsing circle
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(animateCircle ? 1.2 : 1.0)
                        .opacity(animateCircle ? 0.7 : 0.2)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: animateCircle
                        )
                    
                    // Main circle that changes color based on state
                    Circle()
                        .fill(isListening ? (voiceActivityDetected ? Color.red : Color.orange) : Color.purple)
                        .frame(width: 60, height: 60)
                        .scaleEffect(circleScale)
                        .animation(
                            Animation.spring(response: 0.3, dampingFraction: 0.6),
                            value: circleScale
                        )
                    
                    // Icon that shows current state
                    Group {
                        if isListening {
                            if voiceActivityDetected {
                                Image(systemName: "waveform")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "ear")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        } else if isSpeaking {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                }
                .onTapGesture {
                    if isListening {
                        stopListening()
                    } else {
                        startContinuousListening()
                    }
                }
                .padding(.bottom, 30)
                
                // Voice selection and persona
                HStack {
                    Menu {
                        ForEach(GeminiPersona.allCases) { persona in
                            Button(action: {
                                currentPersona = persona
                                updateGeminiPersona()
                            }) {
                                Label(persona.name, systemImage: persona.iconName)
                            }
                        }
                    } label: {
                        Label(currentPersona.name, systemImage: currentPersona.iconName)
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Toggle for showing chat history
                    Button(action: {
                        withAnimation {
                            showTextMessages.toggle()
                        }
                    }) {
                        Image(systemName: showTextMessages ? "message.fill" : "message")
                            .foregroundColor(.purple)
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(20)
                    }
                    
                    // Voice selection button
                    Button(action: {
                        showVoiceSettings.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.purple)
                            Text(selectedVoice.rawValue)
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // Transcription text (only shown when actively listening)
                if isListening && !transcript.isEmpty {
                    Text(transcript)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }
            }
            .zIndex(1)
            
            // Chat history overlay (shown when toggled)
            if showTextMessages {
                VStack {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                }
                                .onChange(of: messages.count) { _ in
                                    if let lastMessage = messages.last {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding()
                .zIndex(0)
                .transition(.move(edge: .top))
            }
        }
        .onAppear {
            animateCircle = true
            setupGeminiModel()
            // Auto-start listening when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startContinuousListening()
            }
        }
        .onDisappear {
            speechRecognizer.stopTranscribing()
            listeningTimeout?.invalidate()
        }
        .sheet(isPresented: $showVoiceSettings) {
            GeminiVoiceSettingsView(selectedVoice: $selectedVoice, onVoiceSelected: { voice in
                selectedVoice = voice
                setupGeminiModel() // Reinitialize the model with the new voice
            })
        }
    }
    
    private func setupGeminiModel() {
        // Initialize the Gemini model
        geminiModel = timerManager.getGeminiManager().createLiveModel(voiceName: selectedVoice)
        
        // Set up the chat session for this model
        if let model = geminiModel {
            chatSession = model.startChat()
            isConnected = true
            updateGeminiPersona() // Set initial persona
        } else {
            isConnected = false
        }
    }
    
    private func updateGeminiPersona() {
        // Update the system instruction based on selected persona
        Task {
            if let chat = chatSession {
                do {
                    // Set the persona by sending a system message
                    let response = try await chat.sendMessage(currentPersona.systemPrompt)
                    print("Persona set to: \(currentPersona.name)")
                } catch {
                    print("Error setting persona: \(error)")
                }
            }
        }
    }
    
    private func startContinuousListening() {
        guard isConnected else {
            // If not connected, show an error message
            addMessage(content: "I'm still connecting to the voice service. Please try again in a moment.", isUser: false)
            speakText("I'm still connecting to the voice service. Please try again in a moment.")
            return
        }
        
        isListening = true
        circleScale = 1.3
        transcript = ""
        voiceActivityDetected = false
        
        // Start speech recognition
        speechRecognizer.transcribe { result in
            // Update transcript and detect voice activity
            if result != transcript {
                // Voice activity detected
                voiceActivityDetected = true
                transcript = result
                
                // Reset timeout when voice activity is detected
                self.resetListeningTimeout()
            }
        }
        
        // Set initial timeout
        resetListeningTimeout()
    }
    
    private func resetListeningTimeout() {
        // Cancel existing timer
        listeningTimeout?.invalidate()
        
        // Create new timer - if no voice activity for 3 seconds, process the input
        listeningTimeout = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            guard self.isListening else { return }
            
            if !self.transcript.isEmpty {
                // If we have a transcript and no voice activity for 3 seconds, process it
                self.processTranscript()
            } else {
                // No transcript yet, just wait and listen more
                self.resetListeningTimeout()
            }
        }
    }
    
    private func processTranscript() {
        let currentTranscript = transcript
        
        if !currentTranscript.isEmpty {
            // Add user message to history but don't show UI if showTextMessages is false
            addMessage(content: currentTranscript, isUser: true)
            
            // Process user input with Gemini
            sendMessageToGemini(currentTranscript)
            transcript = ""
            voiceActivityDetected = false
        }
        
        // Continue listening for the next input
        resetListeningTimeout()
    }
    
    private func stopListening() {
        speechRecognizer.stopTranscribing()
        listeningTimeout?.invalidate()
        isListening = false
        circleScale = 1.0
        voiceActivityDetected = false
        
        if !transcript.isEmpty {
            addMessage(content: transcript, isUser: true)
            sendMessageToGemini(transcript)
            transcript = ""
        }
    }
    
    private func sendMessageToGemini(_ input: String) {
        // Check if user wants to start the timer
        if input.lowercased().contains("start") || 
           input.lowercased().contains("begin") || 
           input.lowercased().contains("yes") {
            
            // If it looks like a confirmation to start
            if messages.count > 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let convo = messages.map { $0.content }.joined(separator: "\n")
                    timerManager.startTimerWithConversation(convo)
                }
                
                let finalMessage = "Great! Starting your Pomodoro session now. Focus well!"
                addMessage(content: finalMessage, isUser: false)
                speakText(finalMessage)
                return
            }
        }
        
        // Use Chat API to send the message
        Task {
            do {
                if let chat = chatSession {
                    let response = try await chat.sendMessage(input)
                    
                    DispatchQueue.main.async {
                        if let responseText = response.text {
                            // Add the response
                            addMessage(content: responseText, isUser: false)
                            speakText(responseText)
                        } else {
                            let fallbackMessage = "I'm not sure how to respond to that. Can you try rephrasing?"
                            addMessage(content: fallbackMessage, isUser: false)
                            speakText(fallbackMessage)
                        }
                    }
                } else {
                    // Fallback if chat session isn't available
                    DispatchQueue.main.async {
                        let mockResponse = "I'm here to help you plan your work session. What specific task will you be focusing on today?"
                        addMessage(content: mockResponse, isUser: false)
                        speakText(mockResponse)
                    }
                }
            } catch {
                print("Error sending message to Gemini: \(error)")
                
                DispatchQueue.main.async {
                    let errorMessage = "I'm having trouble connecting. Let's focus on your task - what are you working on today?"
                    addMessage(content: errorMessage, isUser: false)
                    speakText(errorMessage)
                }
            }
        }
    }
    
    private func addMessage(content: String, isUser: Bool, isThinking: Bool = false) {
        let message = ChatMessage(id: UUID(), content: content, isUser: isUser, isThinking: isThinking)
        DispatchQueue.main.async {
            messages.append(message)
        }
    }
    
    private func speakText(_ text: String) {
        let speechSynthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice based on the selected voice
        switch selectedVoice {
        case .aoede:
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        case .charon:
            utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Alex-compact")
        case .fenrir:
            utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Daniel-compact")
        case .kore:
            utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-compact")
        case .puck:
            utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Tom-compact")
        }
        
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        // Update speaking state after the speech is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.05) {
            isSpeaking = false
        }
    }
}

struct GeminiVoiceSettingsView: View {
    @Binding var selectedVoice: GeminiAPIManager.GeminiVoice
    var onVoiceSelected: (GeminiAPIManager.GeminiVoice) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gemini Live API Voices")) {
                    ForEach(GeminiAPIManager.GeminiVoice.allCases) { voice in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(voice.rawValue)
                                    .font(.headline)
                                Text(voice.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedVoice == voice {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVoice = voice
                            onVoiceSelected(voice)
                        }
                    }
                }
                
                Section(header: Text("About Gemini Voices"), footer: Text("These voices are part of the Gemini Live API and provide natural-sounding speech synthesis.")) {
                    Text("Select a voice that will be used for the AI assistant's responses during your Pomodoro sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Voice Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let isThinking: Bool
    let timestamp = Date()
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                Text(message.content)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: .trailing)
            } else {
                HStack(alignment: .top) {
                    // AI Avatar
                    Circle()
                        .fill(Color.purple.opacity(0.8))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "brain")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .padding(.trailing, 5)
                    
                    if message.isThinking {
                        ThinkingIndicator()
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(maxWidth: 280, alignment: .leading)
                    } else {
                        Text(message.content)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                }
                
                Spacer()
            }
        }
        .id(message.id)
    }
}

struct ThinkingIndicator: View {
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    @State private var offset3: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .offset(y: offset1)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .offset(y: offset2)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .offset(y: offset3)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever()) {
                offset1 = -5
            }
            
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.2)) {
                offset2 = -5
            }
            
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.4)) {
                offset3 = -5
            }
        }
    }
}

// Speech recognition using AVFoundation
class SpeechRecognizer: NSObject, ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    var transcript: ((String) -> Void)?
    
    func transcribe(completion: @escaping (String) -> Void) {
        transcript = completion
        
        requestAuthorization { [weak self] in
            guard let self = self else { return }
            
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                self.task = self.recognizer?.recognitionTask(with: self.request) { result, error in
                    guard let result = result else {
                        if let error = error {
                            print("Speech recognition error: \(error)")
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completion(result.bestTranscription.formattedString)
                    }
                }
                
                let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
                audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    self.request.append(buffer)
                }
                
                audioEngine.prepare()
                try audioEngine.start()
            } catch {
                print("Audio engine setup error: \(error)")
            }
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.cancel()
        task = nil
    }
    
    private func requestAuthorization(completion: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion()
                default:
                    print("Speech recognition not authorized")
                }
            }
        }
    }
}

// Enum for different Gemini personas
enum GeminiPersona: String, CaseIterable, Identifiable {
    case assistant
    case noteTaker
    case mentor
    case manager
    case advocate
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .assistant: return "Assistant"
        case .noteTaker: return "Note Taker"
        case .mentor: return "Mentor"
        case .manager: return "Manager"
        case .advocate: return "Advocate"
        }
    }
    
    var iconName: String {
        switch self {
        case .assistant: return "person.circle"
        case .noteTaker: return "note.text"
        case .mentor: return "graduationcap"
        case .manager: return "briefcase"
        case .advocate: return "hand.raised"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .assistant:
            return "You are a friendly AI assistant named PomoPilot that helps people stay focused and productive. Keep responses short and helpful."
        case .noteTaker:
            return "You are a detailed note-taker. Listen carefully to what the user is saying and organize their thoughts into clear notes. Focus on capturing key points and details they mention. Keep responses short and helpful."
        case .mentor:
            return "You are a supportive mentor providing guidance and feedback. Ask insightful questions that help the user reflect on their work and growth. Provide encouraging but honest feedback. Keep responses short and helpful."
        case .manager:
            return "You are an efficient project manager. Help the user stay on track with their goals, track progress, and manage their time effectively. Be direct and goal-oriented. Keep responses short and helpful."
        case .advocate:
            return "You are a supportive advocate who helps the user recognize their accomplishments and strengths. Highlight positive aspects of their work and help them overcome negative self-talk. Keep responses short and helpful."
        }
    }
} 


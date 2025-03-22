import SwiftUI
import AVFoundation

struct VoiceInteractionView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var animateCircle = false
    @State private var circleScale: CGFloat = 1.0
    @State private var messages: [ChatMessage] = []
    @State private var isListening = false
    @State private var isSpeaking = false
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var transcript = ""
    
    var body: some View {
        NavigationView {
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
                }
                
                Spacer()
                
                // Voice indicator
                ZStack {
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
                    
                    // Main circle
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 60, height: 60)
                        .scaleEffect(circleScale)
                        .animation(
                            Animation.spring(response: 0.3, dampingFraction: 0.6),
                            value: circleScale
                        )
                    
                    // Microphone icon
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .onTapGesture {
                    if isListening {
                        stopListening()
                    } else {
                        startListening()
                    }
                }
                .padding(.bottom, 30)
                
                // Transcription text
                if isListening {
                    Text(transcript.isEmpty ? "Listening..." : transcript)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }
            }
            .navigationTitle("Start Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        let convo = messages.map { $0.content }.joined(separator: "\n")
                        timerManager.startTimerWithConversation(convo)
                    }
                }
            }
            .onAppear {
                animateCircle = true
                startConversation()
            }
            .onDisappear {
                speechRecognizer.stopTranscribing()
            }
        }
    }
    
    private func startConversation() {
        // Add initial welcome message from Gemini
        addMessage(content: "Hi there! I'm here to help you start your Pomodoro session. What would you like to work on today?", isUser: false)
    }
    
    private func startListening() {
        isListening = true
        circleScale = 1.3
        transcript = ""
        
        speechRecognizer.transcribe { result in
            transcript = result
        }
    }
    
    private func stopListening() {
        speechRecognizer.stopTranscribing()
        isListening = false
        circleScale = 1.0
        
        if !transcript.isEmpty {
            addMessage(content: transcript, isUser: true)
            
            // Process user input with Gemini
            processUserInput(transcript)
            transcript = ""
        }
    }
    
    private func processUserInput(_ input: String) {
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
                addMessage(content: "Great! Starting your Pomodoro session now. Focus well!", isUser: false)
                return
            }
        }
        
        // Otherwise send to Gemini for a response
        addMessage(content: "Thinking...", isUser: false)
        
        // This would call the Gemini API
        timerManager.geminiManager.processStartConversation(input: input) { response in
            // Remove the thinking message
            if let lastIndex = messages.lastIndex(where: { !$0.isUser }) {
                messages.remove(at: lastIndex)
            }
            
            // Add the actual response
            addMessage(content: response, isUser: false)
            
            // If this is asking if ready to start, add a slight delay then ask
            if response.contains("ready to start") || response.contains("shall we begin") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    speakText(response)
                }
            } else {
                speakText(response)
            }
        }
    }
    
    private func addMessage(content: String, isUser: Bool) {
        let message = ChatMessage(id: UUID(), content: content, isUser: isUser)
        DispatchQueue.main.async {
            messages.append(message)
        }
    }
    
    private func speakText(_ text: String) {
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        
        // Set speaking to false when done
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.05) {
            isSpeaking = false
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
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
                    Image("gemini_icon")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .padding(.trailing, 5)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 36, height: 36)
                        )
                    
                    Text(message.content)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 280, alignment: .leading)
                }
                
                Spacer()
            }
        }
        .id(message.id)
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
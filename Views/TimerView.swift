import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Timer type indicator
            Text(timerManager.currentTimerType.rawValue)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Progress circle
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(timerColorForType)
                
                Circle()
                    .trim(from: 0.0, to: animateProgress ? CGFloat(timerManager.progress) : 0)
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(timerColorForType)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                
                VStack(spacing: 10) {
                    // Time remaining
                    Text(timeString(time: timerManager.timeRemaining))
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    // Cycle indicator
                    Text("Cycle \(timerManager.currentCycle)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 300, height: 300)
            .onAppear {
                animateProgress = true
            }
            
            // Voice interaction button
            if timerManager.isRunning {
                Button(action: {
                    timerManager.showVoiceInteractionDuringTimer()
                }) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                        Text("Talk to Gemini")
                            .fontWeight(.medium)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.purple.opacity(0.2))
                    )
                    .foregroundColor(.purple)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Control buttons
            HStack(spacing: 30) {
                Button(action: {
                    timerManager.isRunning ? timerManager.pause() : timerManager.start()
                    
                    // Start a new session if there isn't an active one
                    if sessionManager.currentSession == nil && !timerManager.isRunning {
                        sessionManager.startNewSession()
                    }
                }) {
                    Image(systemName: timerManager.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(timerManager.isRunning ? .orange : .green)
                }
                
                Button(action: {
                    timerManager.stop()
                    
                    // Complete current session if one is active
                    if sessionManager.currentSession != nil {
                        sessionManager.completeCurrentSession()
                    }
                }) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $timerManager.shouldShowInputPrompt) {
            WorkInputView()
        }
        // New sheet for session start prompt
        .sheet(isPresented: $timerManager.shouldShowSessionStartPrompt) {
            SessionStartInputView()
        }
        // New sheet for voice interaction
        .sheet(isPresented: $timerManager.shouldShowVoiceInteraction) {
            VoiceInteractionView()
        }
        // AI Reminder Alert (2 minutes before end of work session)
        .alert("Time to wrap up!", isPresented: $timerManager.showAIReminder) {
            Button("Got it", role: .cancel) {
                timerManager.dismissAIInteraction()
            }
        } message: {
            Text(timerManager.aiMessage)
        }
        // AI Break Engagement Sheet
        .sheet(isPresented: $timerManager.showAIBreakEngagement) {
            BreakEngagementView()
        }
    }
    
    // Format seconds into minutes:seconds
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Get color based on timer type
    var timerColorForType: Color {
        switch timerManager.currentTimerType {
        case .work:
            return .blue
        case .shortBreak:
            return .green
        case .longBreak:
            return .purple
        case .delay:
            return .orange
        }
    }
}

// New view for session start input
struct SessionStartInputView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var input = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("What are you working on today?")
                    .font(.headline)
                
                TextEditor(text: $input)
                    .padding(10)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                
                HStack {
                    Button("Skip") {
                        timerManager.startTimerWithInput("")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Start Session") {
                        timerManager.startTimerWithInput(input)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
}

// View for AI break engagement
struct BreakEngagementView: View {
    @EnvironmentObject var timerManager: TimerManager
    @FocusState private var isFeedbackFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Initial AI message
                AIMessageBubble(message: timerManager.aiMessage)
                
                if timerManager.showBreakFeedbackPrompt {
                    // User feedback input
                    VStack(alignment: .leading) {
                        Text("Your response:")
                            .font(.headline)
                            .padding(.leading, 5)
                        
                        TextEditor(text: $timerManager.userBreakFeedback)
                            .padding(10)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .focused($isFeedbackFocused)
                            .onAppear {
                                isFeedbackFocused = true
                            }
                        
                        HStack {
                            Button("Skip") {
                                timerManager.dismissAIInteraction()
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Submit") {
                                timerManager.submitBreakFeedback()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(timerManager.userBreakFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.top)
                }
                
                if timerManager.showAIBreakResponse {
                    // AI response to user feedback
                    AIMessageBubble(message: timerManager.aiBreakResponse)
                    
                    Button("Continue Break") {
                        timerManager.dismissAIInteraction()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Break Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        timerManager.dismissAIInteraction()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// AI message bubble component
struct AIMessageBubble: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.purple)
                .padding(.trailing, 5)
            
            Text(message)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.1))
                )
            
            Spacer()
        }
    }
}

struct WorkInputView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var input = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("What did you accomplish?")
                    .font(.headline)
                
                TextEditor(text: $input)
                    .padding(10)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                
                HStack {
                    Button("Skip") {
                        timerManager.submitInput()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Submit") {
                        timerManager.currentInput = input
                        timerManager.submitInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Work Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
} 
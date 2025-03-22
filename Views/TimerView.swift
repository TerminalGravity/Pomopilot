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
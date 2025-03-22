# Pomopilot

Pomopilot is an AI-powered Pomodoro timer app that boosts productivity by integrating the classic Pomodoro technique with the Gemini API. It helps users manage their work sessions, provides intelligent insights, and creates comprehensive work logs.

## Features

- **Pomodoro Timer**: Customize your work and break sessions with an easy-to-use timer interface
- **AI Integration**: Interact with the Gemini API during your work sessions and breaks
- **Session Tracking**: Record what you accomplish during each work period
- **Break Engagement**: Receive thoughtful prompts during breaks to help you reflect on your work
- **Comprehensive Reports**: View detailed reports of your work sessions with AI-generated insights
- **Google Docs Export**: Export your session logs to Google Docs for sharing and reviewing

## Getting Started

### Prerequisites

- iOS 16.0 or later
- Xcode 14.0 or later
- Gemini API key (for AI functionality)

### Installation

1. Clone this repository
2. Open the project in Xcode
3. Add your Gemini API key in `Managers/GeminiAPIManager.swift`
4. Build and run the app on your device or simulator

### Setting Up the Gemini API

To use the AI features in Pomopilot, you'll need a Gemini API key:

1. Visit [Google AI Studio](https://makersuite.google.com/) and create an account
2. Generate an API key
3. Open `Managers/GeminiAPIManager.swift` and replace the empty string in `private let apiKey: String = ""` with your API key

## How to Use

1. **Start a Work Session**: Tap the play button to begin a 25-minute work session
2. **Receive AI Reminders**: 2 minutes before your session ends, the AI will remind you to wrap up
3. **Log Your Work**: After each session, record what you accomplished
4. **Break Engagement**: During breaks, the AI will ask reflective questions to help improve your productivity
5. **View Reports**: Check the Reports tab to see your session history and AI-generated insights
6. **Export to Google Docs**: Share your work logs with stakeholders by exporting to Google Docs

## Customization

Visit the Settings tab to customize:
- Work session duration
- Break duration
- Number of cycles before a long break

## Development Notes

- Built with SwiftUI for a modern, responsive interface
- Uses the Gemini API for AI integration
- Implements MVVM architecture with clear separation of concerns
- Follows Apple's Human Interface Guidelines

## Future Enhancements

- Complete Google Docs API integration
- Additional AI-powered productivity insights
- Integration with task management systems
- Team collaboration features 
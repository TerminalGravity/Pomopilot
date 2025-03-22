# Pomopilot

An AI-enhanced Pomodoro timer app for iPhone that helps you track and analyze your productivity.

## Features

- **Chained Pomodoro Timers**: Automatically run multiple Pomodoro cycles with configurable work sessions, short breaks, and long breaks.
- **Session Tracking**: Keep a record of your completed sessions and what you accomplished during each work period.
- **AI Analysis**: Get insights and summaries of your productivity after each complete session.
- **Customizable Settings**: Adjust all timer durations, number of cycles, and delays between timers.
- **Persistent Storage**: Your sessions and settings are saved locally on your device.
- **Background Notifications**: Get notified when timers complete, even when the app is in the background.

## App Structure

The app is built with SwiftUI using a clean architecture:

- **Models**: Data structures for timer settings, work periods, and sessions
- **Managers**: Business logic for timer operations and session management
- **Views**: User interface components

## Usage

1. **Timer Tab**: Start, pause, or stop Pomodoro sessions. Input what you accomplished after each work period.
2. **Reports Tab**: View your past sessions, including AI-generated summaries and details of your work.
3. **Settings Tab**: Customize timer durations and session structure to suit your workflow.

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on your iOS device or simulator

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Future Enhancements

- Integration with a more sophisticated AI service for deeper insights
- Cloud sync for session data across devices
- Custom themes and sound options
- Widget support for quick timer access from home screen
- Apple Watch companion app 
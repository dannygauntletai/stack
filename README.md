# TikTok Clone iOS App

A SwiftUI-based iOS application that implements core TikTok-like features including video playback, feed scrolling, and content uploading.

## Features

- Vertical scrolling video feed with smooth playback
- Video upload functionality with Firebase Storage integration
- Like, comment and share interactions
- User authentication
- Video caching and performance optimizations
- Mute/unmute controls
- Progress indicators and loading states

## Technical Stack

- SwiftUI and UIKit for UI
- MVVM architecture
- Firebase
  - Storage for video/image hosting
  - Firestore for data persistence
  - Authentication for user management
- AVKit for video playback
- Combine for reactive programming
- Async/await for concurrency

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Firebase account and configuration

## Installation

1. Clone the repository
2. Install dependencies via Swift Package Manager
3. Add your `GoogleService-Info.plist` file
4. Build and run

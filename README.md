# Can't Decide

A Flutter app that helps groups make decisions by randomly selecting one finger from multiple people touching the screen.

## How It Works

1. Everyone places a finger on the screen
2. Once 2 or more fingers are detected, a 10-second countdown begins
3. When the countdown ends, one finger is randomly chosen as the "winner"
4. The losing fingers fade away while the winner is highlighted

## Features

- Multi-touch support for multiple participants
- Visual countdown timer with progress indicator
- Unique colors for each finger
- Sound and haptic feedback during countdown
- Animated winner selection

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.4
- iOS or Android device/emulator

### Installation

```bash
flutter pub get
flutter run
```

## Dependencies

- `audioplayers` - Sound effects
- `vibration` - Haptic feedback

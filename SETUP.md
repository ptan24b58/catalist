# Catalist Widget App - Setup Guide

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Xcode (for iOS development)
- Android Studio (for Android development)
- iOS 14.0+ / Android API 24+

## Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **iOS Setup:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Configure App Group:
     - Select the Runner target
     - Go to "Signing & Capabilities"
     - Add "App Groups" capability
     - Create/select group: `group.com.catalist`
   - Add Widget Extension:
     - File → New → Target
     - Select "Widget Extension"
     - Name it "GoalWidget"
     - Add the files from `ios/GoalWidget/` to the extension target
     - Ensure the extension uses the same App Group

3. **Android Setup:**
   - The widget receiver is already configured in `AndroidManifest.xml`
   - Build the app: `flutter build apk` or `flutter build appbundle`

## Running the App

```bash
flutter run
```

## Widget Setup

### iOS
1. Long-press on home screen
2. Tap the "+" button
3. Search for "Catalist"
4. Add the widget to your home screen

### Android
1. Long-press on home screen
2. Tap "Widgets"
3. Find "Catalist"
4. Drag to home screen

## Architecture Notes

- **Flutter App**: Core business logic, goal management, urgency calculation
- **Native Widgets**: Read-only renderers that display snapshot data
- **Shared Storage**: JSON snapshots written by Flutter, read by native widgets
- **Widget Actions**: Native widgets trigger actions via deep links or shared files

## Development

The app follows clean architecture:
- `lib/domain/` - Core models (Goal, MascotState)
- `lib/logic/` - Business logic (UrgencyEngine, MascotEngine)
- `lib/data/` - Data persistence (GoalRepository)
- `lib/widget_snapshot.dart` - Snapshot generation service
- `lib/services/` - Widget action handling

## Testing Widgets

1. Create goals in the Flutter app
2. The widget automatically updates with the most urgent goal
3. Tap "Log Progress" in the widget to test interactions
4. Widget refreshes at scheduled times (morning, midday, evening, midnight)

## Troubleshooting

- **Widget not updating**: Ensure App Group is configured correctly (iOS) or SharedPreferences is accessible (Android)
- **Actions not working**: Check deep link configuration in AndroidManifest.xml and iOS Info.plist
- **Mascot not showing**: Ensure image assets are added (currently using system icons as placeholders)

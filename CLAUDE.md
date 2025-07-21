# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Flutter multi-platform application named "asset_helper" configured for mobile, web, and desktop development.

## Environment Requirements
- Flutter SDK >= 3.4.1
- Java 17 (configured at `/opt/homebrew/opt/openjdk@17`)
- Gradle 8.9

## Development Commands
```bash
# Dependencies
flutter pub get                    # Install dependencies

# Code Quality
flutter analyze                    # Run code analysis and linting
flutter test                      # Run tests

# Development
flutter run                       # Run in debug mode
flutter run -d chrome             # Run on web browser
flutter run -d macos              # Run on macOS

# Building
flutter build apk --debug         # Android APK
flutter build ios --debug --no-codesign  # iOS app (no code signing)
flutter build web                 # Web build
flutter build macos               # macOS app
flutter build linux               # Linux app
flutter build windows             # Windows app
```

## Project Structure
- `/lib/main.dart` - Main application entry point
- `/test/widget_test.dart` - Widget tests
- `/android/` - Android platform configuration (Java 17 compatible)
- `/ios/` - iOS platform configuration
- `/web/` - Web platform configuration
- `/macos/`, `/linux/`, `/windows/` - Desktop platform configurations

## Platform Configuration
- **Android**: Package ID `com.example.asset_helper`, Java 17 compatibility
- **iOS**: Bundle ID uses PRODUCT_BUNDLE_IDENTIFIER, supports all orientations
- **All Platforms**: Configured and ready for deployment

## Code Quality
- Uses `flutter_lints ^3.0.0` for code analysis
- Standard Flutter recommended linting rules in `analysis_options.yaml`

## Testing
- Uses built-in `flutter_test` framework
- Run individual tests: `flutter test test/specific_test.dart`
- Widget testing setup available in `/test/widget_test.dart`

## Dependencies
- `cupertino_icons ^1.0.6` for iOS-style icons
- Minimal dependency setup - add project-specific packages as needed

## Asset Management
Currently no custom assets configured. To add assets:
1. Place files in `/assets/` directory
2. Update `pubspec.yaml` under `flutter: assets:` section
3. Reference with `AssetImage('assets/filename.png')` or similar
# App Icon Generation Instructions

The app icon has been placed in the correct location and the pubspec.yaml has been configured properly. Follow these steps to generate all the required app icons:

## Steps to Generate Icons

1. Open a terminal in the project root directory
2. Run these commands:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## What This Will Do

- The `flutter_launcher_icons` package will:
  - Take the image from `assets/images/app-icon.png`
  - Generate Android icons for all necessary resolutions in the appropriate mipmap directories
  - Create adaptive icons for modern Android devices with the proper foreground/background separation
  - Generate iOS icons if you're building for iOS

## Verifying the Icons

After running the commands, check these locations to confirm the icons were generated:

- Android: 
  - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
  - And their adaptive counterparts in the same directories

- iOS:
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Troubleshooting

If you encounter any issues:

1. Make sure the image file exists at `assets/images/app-icon.png`
2. Verify the image is at least 1024x1024 pixels for best results
3. Check that you have internet access (required for the package to download its dependencies)
4. Try restarting the Flutter development tools

The image you've provided looks great as an app icon and perfectly represents the security focus of the Nidhi-Rakshak app!

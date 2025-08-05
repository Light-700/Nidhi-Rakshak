# App Icon Placement Guide for Nidhi-Rakshak

## Android App Icon Placement

To add your app icon to the Android app, follow these steps:

1. Prepare your app icon image named `ic_launcher.png` in the following sizes:
   - 48x48 pixels for mdpi
   - 72x72 pixels for hdpi
   - 96x96 pixels for xhdpi
   - 144x144 pixels for xxhdpi
   - 192x192 pixels for xxxhdpi

2. Place these files in their respective directories:
   - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
   - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

3. If you have a single high-resolution icon (e.g., app-icon.png), you can use Android Studio's Image Asset Studio:
   - Right-click on the `res` folder
   - Select "New > Image Asset"
   - Choose "Icon Type" as "Launcher Icons"
   - Select your high-resolution icon file
   - Configure as needed and click "Next" and "Finish"

## iOS App Icon Placement

For iOS, you'll need to place your app icon in:

1. Navigate to `ios/Runner/Assets.xcassets/AppIcon.appiconset`
2. Replace the existing icon files with your own icons in various sizes as defined in the Contents.json file
3. Alternatively, use Xcode to open the project and edit the app icon through the asset catalog

## Flutter App Icon Package (Easiest Method)

The easiest way to add an app icon to your Flutter project is to use the `flutter_launcher_icons` package:

1. Add the dependency to your pubspec.yaml:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   ```

2. Create an app icon configuration in your pubspec.yaml:
   ```yaml
   flutter_launcher_icons:
     android: "ic_launcher"
     ios: true
     image_path: "assets/images/app-icon.png"
     adaptive_icon_background: "#FFFFFF"
     adaptive_icon_foreground: "assets/images/app-icon-foreground.png"
   ```

3. Place your high-resolution app icon (1024x1024 recommended) at `assets/images/app-icon.png`

4. Run the following command to generate icons for all platforms:
   ```
   flutter pub run flutter_launcher_icons
   ```

This method will automatically resize your icon and place it in all the appropriate directories for both Android and iOS.

## Asset Directory

If you're only using the icon within your Flutter app (not as a launcher icon), place it in:

```
assets/images/app-icon.png
```

And reference it in your pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/images/app-icon.png
```

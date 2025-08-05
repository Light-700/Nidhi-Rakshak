# App Icons

Place your app icons in this directory with the following requirements:

1. `app-icon.png` - The main app icon (recommended size 1024x1024px)
2. `app-icon-foreground.png` - The foreground icon for adaptive icons on Android (recommended size 108x108px)

After placing your icons here, run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will generate all the necessary icon sizes for both Android and iOS platforms.

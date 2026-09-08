# Branding assets

Place the AZIMUTH logo here as:

    assets/branding/azimuth_logo.png

Recommended: a PNG on a **white** background (black logo on white). A
square-ish image works best for the app icon; a wider logo also works for the
splash screen. Something around 1024×1024 is ideal.

To invert the original white-on-black logo to black-on-white, use any image
tool — e.g. Photopea (Image → Adjustments → Invert), an online "invert colors"
site, or ImageMagick: `magick azimuth_black.png -negate azimuth_logo.png`.

## Generate the icon & splash (one time, after adding the file)

```bash
flutter pub get
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

Then rebuild the app:

```bash
flutter build apk --release --dart-define-from-file=env.json     # Android
flutter build ipa --dart-define-from-file=env.json               # iOS / TestFlight
```

Configuration lives in `pubspec.yaml` under `flutter_launcher_icons:` and
`flutter_native_splash:` (both use a black background to match the logo).

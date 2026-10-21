# أذان ليبيا — Flutter

Full Flutter conversion of the original Expo/React Native **Athan Libya** app.
Everything runs locally on-device: prayer times, Hijri calendar, the complete
Qalun mushaf, athkar, qibla — no backend required.

## Run in the browser (no emulator needed)

```bash
flutter build web --release --pwa-strategy=none
# serve build/web with any static server (SPA fallback recommended)
```

A ready-made build is included in `build/web` (also shipped as
`athan-libya-web-build.zip`). Iterating:

```bash
flutter run -d web-server --web-port 3000   # dev server with hot reload
```

## Build the Android APK

```bash
flutter build apk --release          # install on any Android device
flutter build appbundle --release    # for Google Play
```

Permissions (location, notifications, vibrate) are already configured in
`android/app/src/main/AndroidManifest.xml`, matching the original app.json.
Prayer notifications are scheduled natively for the next 7 days
(`flutter_local_notifications`, Africa/Tripoli timezone). On web the
notifications toggle intentionally shows the same disclaimer as the original.

## Feature parity with the original

| Feature | Implementation |
|---|---|
| Prayer times | `adhan` Dart package (same library as the original), Egyptian/MWL/Karachi, Shafi asr; Africa/Tripoli fixed UTC+2 formatting |
| Hijri calendar | Umm al-Qura month table generated from ICU (identical to the original's `Intl islamic-umalqura`), tabular fallback outside 1300–1600 AH |
| Quran | Full Qalun mushaf (77,431 words) bundled from `qalun.json`, UthmanicQaloun font, ayah markers |
| Recitation | MP3Quran v3 API, streaming via `just_audio`, offline download (IndexedDB on web / app documents on mobile) |
| Qibla | Great-circle bearing + compass (native sensors / `DeviceOrientationEvent` on web) |
| Athkar | Daily counters persisted per-day |
| Municipalities | All 104 Libyan baladiyat bundled, Arabic/English search |
| Settings persistence | `shared_preferences` (localStorage on web, AsyncStorage-equivalent on mobile) |
| Theme | Exact original hex tokens, light + dark (follows system), full RTL |

## Project layout

```
lib/
  main.dart            app entry, loads bundled data before first frame
  core/                theme tokens, shared widgets, ar-LY formatting
  data/                municipalities, adhkar, quran loader, generated hijri table
  logic/               prayer times, hijri conversion + Islamic events
  services/            location, compass, audio/offline cache, notifications
  state/               preferences ChangeNotifier
  screens/             home, qibla, quran library, surah, athkar, more,
                       hijri calendar, settings, tab shell
```

To regenerate the Hijri table (only needed if you want a wider year range):

```bash
node scripts-gen/gen_hijri_data.js   # see project worklog for the generator
```

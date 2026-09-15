# TeleDrive — Telegram-backed Cloud Storage (Flutter)

A Google Drive-style Android app that uses a Telegram Bot as its storage
backend. Files uploaded manually go to one primary Telegram channel; any
number of additional **Sync Links** can each pair a device folder with its
own Telegram channel for independent background auto-syncing (e.g. a
Lossless Music folder → a dedicated Music channel).

## Features

- Bot Token + primary Channel ID, validated against the real Telegram API.
- Photos / Videos / Audio / Documents tabs with live upload progress.
- SQLite tracking of every file — stays visible and re-downloadable even
  after you delete the local copy.
- **Multiple Sync Links**: link as many (folder → channel) pairs as you
  want; each has its own Auto-Sync toggle and shares one background sync
  schedule.
- Delete a file from the app only, or permanently (also removes the
  Telegram message).

## Getting started

```bash
flutter pub get
flutter run
```

On first launch, enter your **Bot Token** and a **primary Channel ID**.
Add more channels later from Settings → Sync Links (each needs the same
bot added as admin).

## Telegram Bot API limits

| Limit | Value |
|---|---|
| Max upload size | 50 MB |
| Max re-download size (`getFile`) | 20 MB |

## CI: GitHub Actions

`.github/workflows/build.yml` builds a release APK on every push. See the
in-repo comments for optional signing secrets (`KEYSTORE_BASE64`,
`KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`). Build tooling pinned to
versions verified to work: Flutter 3.47.1, Gradle 8.14.2, AGP 8.13.0,
Kotlin 2.3.0.

## Security notes

- Bot Token stored with `flutter_secure_storage` (Android Keystore-backed).
- The app never displays a Telegram file-download URL as a "shareable
  link" — it contains your Bot Token.
- `android:allowBackup="false"` prevents Android's automatic backup from
  copying the encrypted credential store off the device.

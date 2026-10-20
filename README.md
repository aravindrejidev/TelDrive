# TeleDrive — Telegram-backed Cloud Storage (Flutter)

A Google Drive-style Android app that uses a Telegram Bot as its storage
backend. Files uploaded manually go to one primary Telegram channel; any
number of additional **Sync Links** can each pair a device folder with its
own Telegram channel for independent background auto-syncing (e.g. a
Lossless Music folder → a dedicated Music channel).

## What's new in 1.3.0

- **In-app updater.** The app checks GitHub for a newer release every time it
  opens and slides up an animated update sheet with the release notes.
  Download, checksum verification and install all happen inside the app.
- **Manual release workflow.** Builds no longer run on every push. You publish a
  release yourself, by typing the version number (see below).
- The soft "neumorphic" redesign and the sync fixes from 1.2.0.

See [CHANGELOG.md](CHANGELOG.md) for the full list.

## Features

- Bot Token + primary Channel ID, validated against the real Telegram API.
- Photos / Videos / Audio / Documents tabs with live upload progress.
- SQLite tracking of every file — stays visible and re-downloadable even
  after you delete the local copy.
- **Multiple Sync Links**: link as many (folder → channel) pairs as you
  want; each has its own Auto-Sync toggle and shares one background sync
  schedule.
- Delete a file from the app only, or permanently (also removes the
  Telegram message). Removed files are never re-uploaded by Sync.
- Search, sort, upload queue with retry, and "Open in Telegram" for files too
  large for a bot to download.

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
| Photo upload as a compressed photo | 10 MB (TeleDrive sends photos as files by default, so this does not apply) |

## Publishing a release

Releases are built by hand, never automatically.

1. **Write the notes.** Edit `RELEASE_NOTES.md` in the repo root (plain
   Markdown: `##` headings, `-` bullets, `**bold**`) and commit it. This exact
   text becomes the release description and is what people see in the update
   popup.
2. **Run the workflow.** On GitHub open **Actions, Release APK, Run workflow**.
   Type the version number (for example `1.3.1`, digits only) and run it.
3. That is all. The workflow builds a signed APK, attaches it (plus a
   `.sha256` checksum file) to a new release named `v1.3.1`, and uses
   `RELEASE_NOTES.md` as the description.

The version you type is the only place the number lives. It is passed to the
build as the app's version name, and the Android build number is derived from
it (`1.3.1` becomes `10301`), so it always goes up with the version. It refuses
to run if the notes file is empty, the version is malformed, or that version has
already been released.

Use a higher version than the last release, or installed apps will not see it
as an update.

### One-time setup: signing key

Android only installs an update over an existing app when both were signed with
the **same key**. Create one key, keep it safe, and reuse it for every release.
If you lose it, nobody can update in place any more.

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias teledrive \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks     # macOS: base64 -i upload-keystore.jks
```

Add four secrets under **Settings, Secrets and variables, Actions**:
`KEYSTORE_BASE64` (the base64 output), `KEYSTORE_PASSWORD`, `KEY_ALIAS`
(`teledrive` above) and `KEY_PASSWORD`. The workflow stops with a clear error if
any is missing, because an APK signed with a throwaway key could never update
an installed copy.

> The first release signed with your new key cannot update an app that was
> installed from a differently signed APK. Android will report a conflict, and
> the only fix is to uninstall first. Uninstalling erases the app's saved
> Telegram credentials and its file list, so note your Bot Token and Channel ID
> before you do. After that one reinstall, every later release updates in place.

## How the in-app updater works

- On start the app asks GitHub for the latest release of this repository. The
  repository name is supplied by the release workflow
  (`--dart-define=GITHUB_REPO=...`), so there is nothing to configure. A local
  debug build has no repository set and simply skips the check.
- If the release's version is higher than the installed one, an animated sheet
  appears with the notes. **Later** closes it for this session, **Skip this
  version** stops asking about that release, and **Update now** starts the
  download.
- The download shows live progress, speed and time left, can be cancelled or
  hidden, and is checked against the release's SHA-256 before it is offered for
  install. A corrupt or incomplete file is discarded.
- On the first install Android asks for "Install unknown apps" permission for
  TeleDrive; the sheet walks through it.
- Settings has an **About and updates** section for checking by hand.

The repository must be public: the app reads the release anonymously. GitHub
allows 60 anonymous checks per hour per network, far more than this needs.

## Build tooling

Pinned to versions verified to work: Flutter 3.47.1, Gradle 8.14.2,
AGP 8.13.0, Kotlin 2.3.0.

## Security notes

- The release workflow never compiles your Telegram token into the APK, since a
  release is a public download. `--dart-define=DEFAULT_BOT_TOKEN=...` still
  works for a private build you make yourself, but anything defined that way can
  be read back out of the APK, so never use it for something you share.
- Updates are downloaded only from GitHub, checked against a SHA-256, and
  Android refuses to install one that is not signed with the same key as the
  installed app.
- Bot Token stored with `flutter_secure_storage` (Android Keystore-backed).
- The app never displays a Telegram file-download URL as a "shareable
  link" — it contains your Bot Token.
- `android:allowBackup="false"` prevents Android's automatic backup from
  copying the encrypted credential store off the device.

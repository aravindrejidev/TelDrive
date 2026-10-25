# Releasing TeleDrive

This page is for the person publishing TeleDrive: how to cut a release, how the signing key works, and how installed apps find and install updates. Back to the [README](../README.md).

## Publishing a release

Releases are built by hand, never automatically.

1. **Write the notes.** Edit `RELEASE_NOTES.md` in the repo root and commit it. It is plain Markdown (`##` headings, `-` bullets, `**bold**`). This exact text becomes the release description, and it is what people see in the update popup inside the app.
2. **Run the workflow.** On GitHub open **Actions → Release APK → Run workflow**. Type the version number (for example `1.3.1`, digits only) and run it.
3. **That is all.** The workflow builds a signed APK and publishes a release named `v1.3.1` with the APK and a `.sha256` checksum file attached, using `RELEASE_NOTES.md` as the description.

The version you type is the only place the number lives. It is passed to the build as the app's version name, and the Android build number is derived from it (`1.3.1` becomes `10301`), so it always rises with the version.

The workflow refuses to run if the notes file is empty, the version is malformed, or that version has already been released. Always use a higher version than the last release, or installed apps will not see it as an update.

### One-time setup: the signing key

Android only installs an update over an existing app when both were signed with the **same key**. Create one key, keep it safe, and reuse it for every release. If it is lost, nobody can update in place any more.

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias teledrive \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks     # macOS: base64 -i upload-keystore.jks
```

Add four secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | the base64 output above |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `teledrive` (the alias used above) |
| `KEY_PASSWORD` | the key password (the same as the keystore password for a PKCS12 key) |

The workflow stops with a clear error if any of them is missing. An APK signed with a throwaway key could never update an installed copy, so building one would only cause trouble later.

> **First release with a new key.** It cannot update an app that was installed from a differently signed APK. Android reports a conflict, and the only fix is to uninstall first. Uninstalling erases the app's saved Telegram credentials and its file list, so note your Bot Token and Channel ID beforehand. After that one reinstall, every later release updates in place.

## How the in-app updater works

- When the app opens it asks GitHub for the latest release of this repository. The repository name is supplied by the release workflow (`--dart-define=GITHUB_REPO=...`), so there is nothing to configure. A local debug build has no repository set and simply skips the check.
- If the release's version is higher than the installed one, an animated sheet appears with the release notes. **Later** closes it for this session, **Skip this version** stops asking about that release, and **Update now** starts the download.
- The download shows live progress, speed and time left, and can be cancelled or hidden. It is checked against the release's SHA-256 before it is offered for install, and a corrupt or incomplete file is discarded.
- On the first install Android asks for the "Install unknown apps" permission for TeleDrive. The sheet walks through it.
- **Settings → Updates** can check by hand, turn the check on app start off, and clear downloaded updates.

The repository must be public, because the app reads the release anonymously. GitHub allows 60 anonymous checks per hour per network, far more than this needs.

The About screen shows the developer, links and commit from the same build information, so it is filled in for release APKs and hidden in local debug builds.

## Build tooling

Pinned to versions verified to work: Flutter 3.47.1, Gradle 8.14.2, Android Gradle Plugin 8.13.0, Kotlin 2.3.0.

## Security notes

- The release workflow never compiles your Telegram token into the APK, because a release is a public download. `--dart-define=DEFAULT_BOT_TOKEN=...` still works for a private build you make yourself, but anything defined that way can be read back out of the APK, so never use it for something you share.
- Updates are downloaded only from GitHub and checked against a SHA-256. Android also refuses to install one that is not signed with the same key as the installed app.
- The Bot Token is stored with `flutter_secure_storage` (Android Keystore-backed).
- The app never shows a Telegram file-download URL as a "shareable link", because it contains your Bot Token.
- `android:allowBackup="false"` stops Android's automatic backup from copying the encrypted credential store off the device.

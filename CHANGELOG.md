# Changelog

## 1.3.0

### In-app updater
- Checks GitHub for a newer release whenever the app opens and, if there is
  one, slides up an update sheet showing the release notes.
- Animated throughout: a blurred backdrop and spring-up card, a breathing
  badge whose ring fills as the download advances, an icon that changes with
  each stage, staggered release notes, and a shake when something fails.
- Downloads inside the app with live progress, speed and time remaining.
  It can be cancelled or hidden, and a finished download is reused.
- Verifies the APK against the release's SHA-256 before installing, and asks
  for the "install unknown apps" permission with an explanation.
- "Later" and "Skip this version"; a dot on the Settings button while an
  update is waiting; a check-for-updates section in Settings.

### Releases
- The build workflow no longer runs on every push. `release.yml` is started by
  hand, takes the version number as an input, and publishes a GitHub Release
  using `RELEASE_NOTES.md` from the repo root.
- It refuses to build without the signing key, because an APK signed with a
  throwaway key can never update an installed app.
- The Telegram token is no longer compiled into release builds.

## 1.2.0

### Redesign
- New soft "neumorphic" interface: every surface is raised from, or pressed
  into, one base material, lit from the top-left. Light and dark themes, with
  a System / Light / Dark switch in Settings.
- Custom controls: raised buttons that press in, inset text fields, toggle
  switches, groove progress bars, tab strip, sheets and dialogs.
- Edge-to-edge layout; the status and navigation bars follow the theme.

### Bugs fixed
- **Removed files came back.** Removing a file from the app, or deleting it
  permanently, left it on the phone, so the next sync uploaded it again. Removed
  files are now remembered, and uploads are matched on the original device path
  (which a later re-download no longer overwrites).
- **Photos were recompressed.** `sendPhoto` lets Telegram shrink images and
  rejects anything over 10 MB. Photos now go out as files by default (a switch
  in Settings turns this off), and only formats Telegram supports natively use
  the typed upload methods. FLAC, WAV, MKV and similar go out as documents.
- **Uploads failed on unexpected replies.** If Telegram answered with a
  different media type than requested, the upload was treated as failed even
  though the file was posted. Every media type in the reply is now handled.
- **Rate limits.** A large sync hit Telegram's rate limit and failed the rest of
  the batch. 429 replies are now waited out and retried, and uploads are paced.
- **Half-written files.** Sync could upload a file that was still being copied
  or downloaded. Recently modified files and temporary files (`.part`,
  `.crdownload`, `.tmp`) are now skipped until they settle.
- **Upload progress** reached 100% immediately because the whole file was
  buffered first. It now follows the data actually sent.
- **Failed deletes left the screen stuck.** An error while deleting from
  Telegram was unhandled. It is now explained, with the option to remove the
  file from the app only. A message that is already gone counts as deleted.
- **Broken downloads.** A failed download left a partial file that looked like
  a finished one, and two files with the same name overwrote each other.
  Downloads now go to a temporary file first and are stored per file.
- **Background sync** could run past Android's time limit, and could run twice
  at once. It now has a time budget and a guard.
- **Reconnecting** left Auto-Sync switched on in the list but not scheduled.
- Network sockets were never closed.

### Improvements
- Search and sort (newest, oldest, name, size).
- Uploads run two at a time in a visible queue, with Retry for failed ones.
- Files over 20 MB, which a bot cannot download, now offer "Open in Telegram".
- Sync Links show when they last synced and have a "Sync now" button each.
- Sync reports files over the 50 MB limit and the reason for a failure.
- Setup checks that the bot is an admin who can post, and accepts `t.me`
  links or a bare channel number.
- A file picked in the wrong tab is filed under its real type.
- Storage overview with size per category.
- No permission prompt before picking files (the system picker needs none).

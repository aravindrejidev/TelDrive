/// A user-facing error with a message that is safe to show as-is.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns any thrown object into text suitable for a snackbar or dialog.
String friendlyError(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
}

/// Accepts the many ways people write a channel reference and returns the
/// form the Bot API expects:
///   * `https://t.me/name`            -> `@name`
///   * `https://t.me/c/123456789/5`   -> `-100123456789`
///   * `name`                         -> `@name`
///   * `1234567890` (digits only)     -> `-1001234567890`
///   * `@name` / `-100…`              -> unchanged
String normalizeChannelId(String input) {
  final value = input.trim();
  if (value.isEmpty) return value;

  final link = RegExp(
    r'^(?:https?://)?(?:t|telegram)\.me/(.+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (link != null) {
    final path = link.group(1)!.split('?').first;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts.first == 'c' && RegExp(r'^\d+$').hasMatch(parts[1])) {
      return '-100${parts[1]}';
    }
    if (parts.isNotEmpty && !parts.first.startsWith('+') && parts.first != 'joinchat') {
      return '@${parts.first}';
    }
    return value;
  }

  if (RegExp(r'^\d{6,}$').hasMatch(value)) return '-100$value';
  if (RegExp(r'^[A-Za-z][A-Za-z0-9_]{3,}$').hasMatch(value)) return '@$value';
  return value;
}

/// A deep link to a message inside the channel, or null when the channel has
/// no linkable form (for example a legacy group id).
///
/// This link never contains the Bot Token, so it is safe to open or share.
Uri? telegramMessageUri(String? channelId, int messageId) {
  if (channelId == null || channelId.isEmpty) return null;
  if (channelId.startsWith('-100') && channelId.length > 4) {
    return Uri.parse('https://t.me/c/${channelId.substring(4)}/$messageId');
  }
  if (channelId.startsWith('@') && channelId.length > 1) {
    return Uri.parse('https://t.me/${channelId.substring(1)}/$messageId');
  }
  return null;
}

/// Makes a remote file name safe to use on the local file system.
String sanitizeFileName(String name) {
  var cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  while (cleaned.startsWith('.')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.isEmpty) return 'file';
  if (cleaned.length > 150) {
    final dot = cleaned.lastIndexOf('.');
    final ext = (dot > 0 && cleaned.length - dot <= 10) ? cleaned.substring(dot) : '';
    cleaned = cleaned.substring(0, 150 - ext.length) + ext;
  }
  return cleaned;
}

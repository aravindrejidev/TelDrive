import 'package:flutter/foundation.dart';

/// A `major.minor.patch` version, compared number by number (so 1.10.0 is
/// newer than 1.9.0, which plain string comparison gets wrong).
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Reads the first `1.2.3`-style number in [raw], so tags such as `v1.3.0`
  /// and `release-1.3` both work. A missing patch number counts as 0.
  static AppVersion? tryParse(String raw) {
    final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// One published release that has an APK attached.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.apkName,
    required this.apkUrl,
    required this.apkBytes,
    required this.pageUrl,
    this.sha256,
    this.sha256Url,
    this.publishedAt,
  });

  final AppVersion version;
  final String tag;

  /// The release description, in Markdown.
  final String notes;

  final String apkName;
  final String apkUrl;
  final int apkBytes;
  final String pageUrl;

  /// Expected SHA-256 of the APK when GitHub reported it directly.
  final String? sha256;

  /// A `.sha256` file attached to the release, used when [sha256] is absent.
  final String? sha256Url;

  final DateTime? publishedAt;
}

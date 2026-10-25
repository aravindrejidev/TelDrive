/// Facts about this build that the release workflow supplies with
/// `--dart-define`. A local debug build has none of them, so everything here
/// quietly reports "not available" instead of failing.
class AppInfo {
  AppInfo._();

  /// `owner/name` of the GitHub repository the app was built from.
  static const String repository = String.fromEnvironment('GITHUB_REPO');

  /// The commit the build was made from.
  static const String commit = String.fromEnvironment('GIT_SHA');

  static bool get hasRepository => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repository);

  static String? get owner => hasRepository ? repository.split('/').first : null;

  static String get shortCommit => commit.length > 7 ? commit.substring(0, 7) : commit;

  static Uri? get repositoryUri =>
      hasRepository ? Uri.parse('https://github.com/$repository') : null;

  static Uri? get issuesUri =>
      hasRepository ? Uri.parse('https://github.com/$repository/issues') : null;

  static Uri? get releasesUri =>
      hasRepository ? Uri.parse('https://github.com/$repository/releases') : null;

  static Uri? get ownerUri => owner == null ? null : Uri.parse('https://github.com/$owner');

  /// GitHub serves every account's picture at `github.com/<name>.png`.
  static String? get ownerAvatarUrl =>
      owner == null ? null : 'https://github.com/$owner.png?size=160';
}

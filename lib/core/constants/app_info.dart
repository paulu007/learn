/// Single source of truth for app identity + version (spec §68, §69).
/// The CI workflow derives its artifact names and .deb version from these.
abstract final class AppInfo {
  static const String name = 'E';
  static const String tagline =
      'Your language. Your lessons. Your pace. Your progress.';

  /// Semantic version shown in Settings and stamped into releases.
  /// Bump on every user-facing release: MAJOR.MINOR.PATCH.
  static const String version = '1.0.0';

  /// Artifact file stems per spec §68 (version injected by CI):
  ///   `E-<version>-android.apk`, `E-<version>-windows.zip`,
  ///   `E-<version>-linux.deb`, `E-<version>-linux.rpm`
  /// macOS is parked until a macos/ runner folder exists (spec §64
  /// lists it as a goal; enabled via `flutter create --platforms=macos`).
  static String artifact(String platform, String ext) =>
      'E-$version-$platform.$ext';
}

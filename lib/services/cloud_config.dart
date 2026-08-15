import 'package:flutter/foundation.dart';

/// Centralized cloud environment configuration.
///
/// Debug builds may use the bundled development project for backwards
/// compatibility. Release builds must either provide explicit Supabase values
/// or opt in to the bundled development project for an internal staging APK.
class CloudConfig {
  CloudConfig._();

  static const String environment = String.fromEnvironment(
    'HALAQAH_ENV',
    defaultValue: 'development',
  );

  static const String _configuredUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _configuredPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const bool _allowBundledDevelopmentProject = bool.fromEnvironment(
    'HALAQAH_ALLOW_BUNDLED_DEV_SUPABASE',
    defaultValue: false,
  );

  // Development-only compatibility values used by existing local installs.
  // They are publishable client credentials, not privileged secrets.
  static const String _bundledDevelopmentUrl =
      'https://mcckekgvwtqtpwtslwqf.supabase.co';
  static const String _bundledDevelopmentPublishableKey =
      'sb_publishable_TksdkEVcn6VvNGVVjXNEpg_PkRZTdxz';

  static const String authRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'halaqah://login-callback',
  );

  static bool get usesBundledDevelopmentProject =>
      _configuredUrl.trim().isEmpty || _configuredPublishableKey.trim().isEmpty;

  static String get projectUrl {
    _validateEnvironmentName();
    final configured = _configuredUrl.trim();
    if (configured.isNotEmpty) return configured;
    if (_canUseBundledDevelopmentProject) return _bundledDevelopmentUrl;
    throw StateError(
      'SUPABASE_URL is required for release builds. '
      'Use --dart-define=SUPABASE_URL=... or explicitly opt into the bundled '
      'development project for a staging-only APK.',
    );
  }

  static String get publishableKey {
    _validateEnvironmentName();
    final configured = _configuredPublishableKey.trim();
    if (configured.isNotEmpty) return configured;
    if (_canUseBundledDevelopmentProject) {
      return _bundledDevelopmentPublishableKey;
    }
    throw StateError(
      'SUPABASE_PUBLISHABLE_KEY is required for release builds.',
    );
  }

  static bool get _canUseBundledDevelopmentProject =>
      !kReleaseMode || _allowBundledDevelopmentProject;

  static void validate() {
    final url = Uri.tryParse(projectUrl);
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
    }
    final key = publishableKey.trim();
    if (key.length < 20) {
      throw StateError('SUPABASE_PUBLISHABLE_KEY is missing or invalid.');
    }
    if (environment == 'production' && usesBundledDevelopmentProject) {
      throw StateError(
        'Production builds cannot fall back to the bundled development Supabase project.',
      );
    }
  }

  static void _validateEnvironmentName() {
    if (!const <String>{'development', 'staging', 'production'}
        .contains(environment)) {
      throw StateError(
        'HALAQAH_ENV must be development, staging, or production.',
      );
    }
  }
}

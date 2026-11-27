class AppEnv {
  static const String _dartDefineGoogleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool _firebaseInitialized = false;
  static String _resolvedGoogleWebClientId = _dartDefineGoogleWebClientId;

  static bool get isCloudConfigured => _firebaseInitialized;

  static String get googleWebClientId => _resolvedGoogleWebClientId.trim();

  static bool get isGoogleSignInConfigured =>
      _firebaseInitialized || googleWebClientId.isNotEmpty;

  static void markFirebaseInitialized({String? nativeGoogleWebClientId}) {
    _firebaseInitialized = true;
    if (_resolvedGoogleWebClientId.trim().isEmpty &&
        nativeGoogleWebClientId != null &&
        nativeGoogleWebClientId.trim().isNotEmpty) {
      _resolvedGoogleWebClientId = nativeGoogleWebClientId.trim();
    }
  }
}

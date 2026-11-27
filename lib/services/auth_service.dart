import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_env.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _googleInitialized = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => AppEnv.isCloudConfigured ? _auth.currentUser : null;

  String? get currentDisplayName {
    final user = currentUser;
    if (user == null) return null;
    final rawName = user.displayName;
    if (rawName != null && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first.trim();
    }
    return null;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final trimmedName = displayName.trim();
    if (trimmedName.isNotEmpty && credential.user != null) {
      await credential.user!.updateDisplayName(trimmedName);
      await credential.user!.reload();
    }
    return credential;
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!AppEnv.isCloudConfigured) {
      throw StateError('Firebase is not configured yet.');
    }

    String? idToken;
    try {
      if (!_googleInitialized) {
        final serverClientId = AppEnv.googleWebClientId;
        await GoogleSignIn.instance.initialize(
          serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
        );
        _googleInitialized = true;
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      idToken = googleUser.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        rethrow;
      }
      // Fall back to Firebase Chrome Custom Tab OAuth (`accounts.google.com`)
      // when Play Services / Credential Manager is restricted on current Wi-Fi.
    } catch (_) {
      // Fall back to Firebase Chrome Custom Tab OAuth.
    }

    if (idToken != null && idToken.isNotEmpty) {
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _auth.signInWithCredential(credential);
    }

    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithProvider(provider);
  }

  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    if (AppEnv.isCloudConfigured) {
      await _auth.signOut();
    }
  }
}

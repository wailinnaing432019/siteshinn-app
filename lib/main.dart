import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_env.dart';

const MethodChannel _deviceChannel = MethodChannel(
  'com.siteshinn.site_shinn/device_settings',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    String? nativeWebClientId;
    try {
      nativeWebClientId =
          await _deviceChannel.invokeMethod<String>('getGoogleWebClientId');
    } catch (_) {}
    AppEnv.markFirebaseInitialized(nativeGoogleWebClientId: nativeWebClientId);
  } catch (_) {
    // Firebase runs in local/offline-only mode when google-services.json
    // is absent (e.g. local dev builds before Firebase config or unit tests).
  }

  runApp(const ProviderScope(child: SiteShinnApp()));
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  if (AppConfig.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(AppConfig.emulatorHost, AppConfig.authEmulatorPort);
    firestore.useFirestoreEmulator(AppConfig.emulatorHost, AppConfig.firestoreEmulatorPort);
  }
  // Built-in offline persistence (no drift/hive).
  firestore.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: 40 * 1024 * 1024);

  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const WipasApp(),
  ));
}

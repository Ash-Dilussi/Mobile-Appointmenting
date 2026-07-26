import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/firebase/firebase_options.dart';
import 'core/logging/logger_service.dart';
import 'core/database/hive_service.dart';
import 'features/call_log/providers/call_log_providers.dart';
import 'features/subscription/data/subscription_repository.dart';
import 'features/subscription/data/subscription_repository_impl.dart';
import 'core/entitlements/entitlement_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive before accessing any boxes
  await HiveService.instance.init();

  await logger.init();
  logger.info('Startup', 'Logger initialized');

  FlutterError.onError = (details) {
    logger.error(
      'FlutterError',
      'Uncaught Flutter error: ${details.exceptionAsString()}',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  logger.info(
      'Startup', 'Calling runApp — heavy init moves to AppInitNotifier');

  runApp(
    ProviderScope(
      overrides: [
        // Existing override
        activeCallStateProvider,

        // Wire concrete SubscriptionRepository
        // The abstract provider throws UnimplementedError by default;
        // this override provides the real implementation.
        subscriptionRepositoryProvider.overrideWithValue(
          SubscriptionRepositoryImpl(
            firestore: FirebaseFirestore.instance,
            subscriptionBox: HiveService.instance.subscriptionBox,
          ),
        ),
      ],
      child: const App(),
    ),
  );
}

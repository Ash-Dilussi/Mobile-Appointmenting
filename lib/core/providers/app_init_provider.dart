import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_options.dart';
import '../../core/database/hive_service.dart';
import '../../core/logging/logger_service.dart';
import '../../seed_dummy_data.dart';

/// Tracks the initialization state of the app.
/// SplashScreen watches this and navigates when it reaches AsyncData.
final appInitProvider =
    AsyncNotifierProvider<AppInitNotifier, bool>(AppInitNotifier.new);

class AppInitNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // 1. Firebase — biggest blocker, run first
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.info('AppInit', 'Firebase initialized');
    } catch (e, st) {
      // App continues in offline/Hive-only mode
      logger.error('AppInit', 'Firebase failed — continuing offline: $e',
          error: e, stackTrace: st);
    }

    // 2. Hive — open all 10 boxes
    final hiveService = HiveService();
    try {
      await hiveService.init();
      logger.info('AppInit', 'HiveService initialized');
    } catch (e, st) {
      logger.error('AppInit', 'HiveService init failed: $e',
          error: e, stackTrace: st);
      rethrow; // Hive is required — surface the error
    }

    // 3. Seed dummy data (dev/debug builds only)
    assert(() {
      seedDummyData(hiveService, force: true);
      return true;
    }());

    // 4. Clean old logs — non-critical, run last
    try {
      await logger.cleanOldLogs(keepDays: 7);
      logger.info('AppInit', 'Old logs cleaned');
    } catch (_) {
      // Never block startup for log cleanup
    }

    return true; // AsyncData(true) → SplashScreen navigates
  }
}
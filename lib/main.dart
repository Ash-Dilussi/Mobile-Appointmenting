import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/hive_service.dart';
import 'core/logging/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger first
  await logger.init();
  await logger.info('main', 'Application starting...');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Clean old logs (keep last 7 days)
  await logger.cleanOldLogs(keepDays: 7);

  // Set up global error handlers
  FlutterError.onError = (details) {
    logger.error(
      'FlutterError',
      'Uncaught Flutter error: ${details.exceptionAsString()}',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize database
  logger.info('main', 'Initializing Hive database...');
  final hiveService = HiveService();
  await hiveService.init();

  logger.info('main', 'Starting app...');
  runApp(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(hiveService),
      ],
      child: const App(),
    ),
  );
}

// Hive service provider
final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('HiveService must be overridden in main.dart');
});

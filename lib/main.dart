import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/logging/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // logger must be ready before any error hooks
  await logger.init();
  logger.info('Startup', 'Logger initialized');

  // Error hook needs logger; set before runApp
  FlutterError.onError = (details) {
    logger.error(
      'FlutterError',
      'Uncaught Flutter error: ${details.exceptionAsString()}',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Must precede first frame to avoid orientation flicker
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Must precede first frame to avoid status bar flicker
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  logger.info('Startup', 'Calling runApp — heavy init moves to AppInitNotifier');

  // runApp called with NO Firebase/Hive/seed awaits above
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
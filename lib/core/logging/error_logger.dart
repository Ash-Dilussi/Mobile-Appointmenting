import 'logger_service.dart';

/// Wraps any function with try-catch and logs errors automatically
Future<T> withErrorLogging<T>({
  required String source,
  required String operation,
  required Future<T> Function() function,
}) async {
  try {
    logger.debug(source, 'Starting: $operation');
    final result = await function();
    logger.debug(source, 'Completed: $operation');
    return result;
  } catch (e, st) {
    logger.error(
      source,
      'Error during: $operation',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

/// Synchronous version of withErrorLogging
T withErrorLoggingSync<T>({
  required String source,
  required String operation,
  required T Function() function,
}) {
  try {
    logger.debug(source, 'Starting: $operation');
    final result = function();
    logger.debug(source, 'Completed: $operation');
    return result;
  } catch (e, st) {
    logger.error(
      source,
      'Error during: $operation',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

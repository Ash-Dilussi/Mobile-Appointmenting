import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Log levels for filtering
enum LogLevel { debug, info, warning, error }

/// Logger service that writes logs to files in the app's documents directory
class LoggerService {
  static LoggerService? _instance;
  static LoggerService get instance => _instance ??= LoggerService._();

  LoggerService._();

  String? _logDirectoryPath;
  bool _initialized = false;

  /// Initialize the logger - must be called before using
  Future<void> init() async {
    if (_initialized) return;

    final directory = await getApplicationDocumentsDirectory();
    _logDirectoryPath = '${directory.path}/logs';

    // Create logs directory if it doesn't exist
    final logDir = Directory(_logDirectoryPath!);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    _initialized = true;

    // Log initialization
    await log(
      LogLevel.info,
      'LoggerService',
      'Logger initialized. Log directory: $_logDirectoryPath',
    );
  }

  /// Get the current log file path (one per day)
  Future<File> _getLogFile() async {
    if (_logDirectoryPath == null) await init();

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filePath = '$_logDirectoryPath/app_$dateStr.log';

    return File(filePath);
  }

  /// Get all log files
  Future<List<File>> getAllLogFiles() async {
    if (_logDirectoryPath == null) await init();

    final logDir = Directory(_logDirectoryPath!);
    if (!await logDir.exists()) return [];

    final files = await logDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.log'))
        .map((entity) => entity as File)
        .toList();

    // Sort by modification time (newest first)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files;
  }

  /// Log a message with timestamp and level
  Future<void> log(
    LogLevel level,
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (!_initialized) await init();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelStr = level.name.toUpperCase().padRight(7);
    final sourceStr = source.length > 30 ? source.substring(0, 30) : source.padRight(30);

    String logLine = '[$timestamp] [$levelStr] [$sourceStr] $message';

    if (error != null) {
      logLine += '\n  Error: $error';
    }

    if (stackTrace != null) {
      logLine += '\n  StackTrace: ${stackTrace.toString().replaceAll('\n', '\n  ')}';
    }

    logLine += '\n';

    // Also print to console in debug mode for logcat visibility
    if (kDebugMode) {
      debugPrint(logLine);
    }

    try {
      final file = await _getLogFile();
      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (_) {
      // Silently ignore logging failures to prevent infinite loops
      // The log entry is lost but the app continues
    }
  }

  /// Log debug message
  Future<void> debug(String source, String message) =>
      log(LogLevel.debug, source, message);

  /// Log info message
  Future<void> info(String source, String message) =>
      log(LogLevel.info, source, message);

  /// Log warning message
  Future<void> warning(String source, String message) =>
      log(LogLevel.warning, source, message);

  /// Log error message
  Future<void> error(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        LogLevel.error,
        source,
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Get recent logs from today (last N lines)
  Future<String> getRecentLogs({int lines = 100}) async {
    try {
      final file = await _getLogFile();
      if (!await file.exists()) return 'No logs for today yet.';

      final content = await file.readAsString();
      final allLines = content.split('\n');

      if (allLines.length <= lines) return content;

      return allLines
          .skip(allLines.length - lines)
          .join('\n');
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  /// Get logs from a specific file
  Future<String> getLogsFromFile(File file) async {
    try {
      if (!await file.exists()) return 'File does not exist.';
      return await file.readAsString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  /// Clear all logs
  Future<void> clearAllLogs() async {
    if (_logDirectoryPath == null) await init();

    final logDir = Directory(_logDirectoryPath!);
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
      await logDir.create();
    }
  }

  /// Delete old log files (keep only last N days)
  Future<void> cleanOldLogs({int keepDays = 7}) async {
    if (_logDirectoryPath == null) await init();

    final logDir = Directory(_logDirectoryPath!);
    if (!await logDir.exists()) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));

    await for (final entity in logDir.list()) {
      if (entity is File && entity.path.endsWith('.log')) {
        final fileName = entity.path.split('/').last;
        final dateStr = fileName.replaceAll('app_', '').replaceAll('.log', '');

        try {
          final fileDate = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (fileDate.isBefore(cutoffDate)) {
            await entity.delete();
            await info('LoggerService', 'Deleted old log file: $dateStr');
          }
        } catch (_) {
          // Skip files that don't match date pattern
        }
      }
    }
  }
}

/// Global logger instance
final logger = LoggerService.instance;

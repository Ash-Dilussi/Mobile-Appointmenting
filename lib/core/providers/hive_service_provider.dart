import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/hive_service.dart';

/// Provider for HiveService singleton.
/// Returns the initialized HiveService.instance directly.
final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService.instance;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/collections/collections.dart';
import '../../../home/presentation/providers/home_provider.dart';

final allCallLogsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAllCallLogs();
});

final missedCallsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchMissedCalls();
});

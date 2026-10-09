import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/collections/collections.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';

final allCallLogsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <CallLog>[])
      : db.watchCallLogsForInstitution(institutionId);
});

final missedCallsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <CallLog>[])
      : db.watchMissedCallsForInstitution(institutionId);
});

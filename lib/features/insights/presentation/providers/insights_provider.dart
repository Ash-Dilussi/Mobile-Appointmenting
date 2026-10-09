import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/insights_data.dart';
import '../../../../core/providers/hive_service_provider.dart';

final appointmentInsightsProvider =
    StreamProvider.family<AppointmentInsights, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchAppointmentInsights(query);
});

final customerInsightsProvider =
    StreamProvider.family<CustomerInsights, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchCustomerInsights(query);
});

final hotServiceInsightsProvider =
    StreamProvider.family<List<RankedInsight>, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchHotServiceInsights(query);
});

final callInsightsProvider =
    StreamProvider.family<CallInsights, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchCallInsights(query);
});

final bookedValueInsightsProvider =
    StreamProvider.family<BookedValueInsights, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchBookedValueInsights(query);
});

final staffInsightsProvider =
    StreamProvider.family<StaffInsights, InsightsQuery>((ref, query) {
  return ref.watch(hiveServiceProvider).watchStaffInsights(query);
});

final legacyExclusionInsightsProvider =
    StreamProvider<LegacyExclusionInsights>((ref) {
  return ref.watch(hiveServiceProvider).watchLegacyExclusionInsights();
});

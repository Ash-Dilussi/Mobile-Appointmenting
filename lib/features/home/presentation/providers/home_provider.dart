import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/hive_service.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

// Hive service provider alias
final homeHiveProvider = Provider<HiveService>((ref) {
  return ref.watch(hiveServiceProvider);
});

// Upcoming appointments provider
final upcomingAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <Appointment>[])
      : db.watchUpcomingAppointmentsForInstitution(institutionId);
});

// Today's appointments stream
final todayAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <Appointment>[])
      : db.watchAppointmentsForDateForInstitution(
          DateTime.now(),
          institutionId,
        );
});

// Today's appointments count
final todayAppointmentsCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  if (institutionId == null) return 0;
  final appointments =
      db.getAppointmentsForDateForInstitution(DateTime.now(), institutionId);
  return appointments.length;
});

// Missed calls count
final missedCallsCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(0)
      : db
          .watchMissedCallsForInstitution(institutionId)
          .map((calls) => calls.length);
});

// Recent call logs provider
final recentCallLogsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <CallLog>[])
      : db
          .watchCallLogsForInstitution(institutionId)
          .map((logs) => logs.take(5).toList());
});

// Services provider
final servicesProvider = StreamProvider<List<Service>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <Service>[])
      : db.watchServicesForInstitution(institutionId);
});

// Service Stations provider
final serviceStationsProvider = StreamProvider<List<ServiceStation>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <ServiceStation>[])
      : db.watchStationsForInstitution(institutionId);
});

// Recent customers provider (for recent clients row)
final recentCustomersProvider = StreamProvider<List<Customer>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  return institutionId == null
      ? Stream.value(const <Customer>[])
      : db
          .watchCustomersForInstitution(institutionId)
          .map((customers) => customers.take(10).toList());
});

// Dashboard stats
class DashboardStats {
  final int upcomingCount;
  final int todayCount;
  final int missedCallsCount;
  final int totalCustomers;

  const DashboardStats({
    this.upcomingCount = 0,
    this.todayCount = 0,
    this.missedCallsCount = 0,
    this.totalCustomers = 0,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  if (institutionId == null) return const DashboardStats();

  final upcoming = db.getUpcomingAppointmentsForInstitution(institutionId);
  final today =
      db.getAppointmentsForDateForInstitution(DateTime.now(), institutionId);
  final missedCalls = db.getMissedCallsForInstitution(institutionId);
  final customers = db.getCustomersForInstitution(institutionId);

  return DashboardStats(
    upcomingCount: upcoming.length,
    todayCount: today.length,
    missedCallsCount: missedCalls.length,
    totalCustomers: customers.length,
  );
});

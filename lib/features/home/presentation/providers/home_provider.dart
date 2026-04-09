import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/hive_service.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../main.dart';

// Hive service provider alias
final homeHiveProvider = Provider<HiveService>((ref) {
  return ref.watch(hiveServiceProvider);
});

// Upcoming appointments provider
final upcomingAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchUpcomingAppointments();
});

// Today's appointments stream
final todayAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAppointmentsForDate(DateTime.now());
});

// Today's appointments count
final todayAppointmentsCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(homeHiveProvider);
  final appointments = db.getAppointmentsForDate(DateTime.now());
  return appointments.length;
});

// Missed calls count
final missedCallsCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchMissedCalls().map((calls) => calls.length);
});

// Recent call logs provider
final recentCallLogsProvider = StreamProvider<List<CallLog>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAllCallLogs().map((logs) => logs.take(5).toList());
});

// Services provider
final servicesProvider = StreamProvider<List<Service>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAllServices();
});

// Recent customers provider (for recent clients row)
final recentCustomersProvider = StreamProvider<List<Customer>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAllCustomers().map((customers) => customers.take(10).toList());
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

  final upcoming = db.getUpcomingAppointments();
  final today = db.getAppointmentsForDate(DateTime.now());
  final missedCalls = db.getMissedCalls();
  final customers = db.getAllCustomers();

  return DashboardStats(
    upcomingCount: upcoming.length,
    todayCount: today.length,
    missedCallsCount: missedCalls.length,
    totalCustomers: customers.length,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/models/calendar_block.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/providers/calendar_providers.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../../core/utils/appointment_notes_formatter.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

// Provider to access HiveService - override in main.dart
// Cache for calendar blocks — keyed by normalized date (no time component)
final _calendarAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  if (institutionId == null) return Stream.value(const <Appointment>[]);
  return ref
      .watch(hiveServiceProvider)
      .watchAppointmentsForInstitution(institutionId);
});

final _calendarServicesProvider = StreamProvider<List<Service>>((ref) {
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  if (institutionId == null) return Stream.value(const <Service>[]);
  return ref.watch(hiveServiceProvider).watchServicesForInstitution(
        institutionId,
      );
});

final combinedCalendarProvider =
    FutureProvider.family<List<CalendarBlock>, DateTime>((ref, date) async {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  // Local Hive appointments
  final hiveService = ref.read(hiveServiceProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  final allAppointments =
      ref.watch(_calendarAppointmentsProvider).asData?.value ??
          (institutionId == null
              ? const <Appointment>[]
              : hiveService.getAppointmentsForInstitution(institutionId));
  final services = ref.watch(_calendarServicesProvider).asData?.value ??
      (institutionId == null
          ? const <Service>[]
          : hiveService.getServicesForInstitution(institutionId));
  final servicesById = {
    for (final service in services)
      if (service.id != null) service.id!: service,
  };
  final localAppts = allAppointments.where((a) {
    return a.startTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
        a.startTime.isBefore(dayEnd);
  }).toList();

  final localBlocks = localAppts.map((a) {
    final service = a.serviceId == null
        ? null
        : servicesById[a.serviceId] ?? hiveService.getServiceById(a.serviceId!);
    return CalendarBlock(
      id: a.id?.toString() ?? '',
      title: service?.title ?? 'Appointment',
      start: a.startTime,
      end: a.endTime,
      source: EventSource.local,
      displayColor: ServiceColorPalette.resolve(service?.colorValue).color,
      subtitle: formatAppointmentNotesForCalendar(a.notes),
    );
  }).toList();

  // Google Calendar events (only if authenticated)
  List<CalendarBlock> googleBlocks = [];
  final authService = ref.read(googleAuthServiceProvider);
  if (authService.isSignedIn) {
    try {
      googleBlocks = await ref
          .read(googleCalendarServiceProvider)
          .fetchExternalEvents(dayStart, dayEnd);
    } catch (e) {
      // Silently degrade — local appointments always show
    }
  }

  // Merge and sort by start time
  final result = [...localBlocks, ...googleBlocks]
    ..sort((a, b) => a.start.compareTo(b.start));

  return result;
});

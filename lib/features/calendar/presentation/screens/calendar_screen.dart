import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/database/hive_service.dart';
import '../../../../shared/widgets/appointment_tile.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';

// Provider that maps each day to a busy level (0.0-1.0) based on appointment count
final calendarBusyDaysProvider = StreamProvider<Map<DateTime, double>>((ref) {
  final db = ref.watch(homeHiveProvider);
  final institutionId = ref.watch(authSessionProvider)?.institutionId;
  final appointments = institutionId == null
      ? Stream.value(const <Appointment>[])
      : db.watchAppointmentsForInstitution(institutionId);
  return appointments.map((appointments) {
    final Map<DateTime, double> busyLevels = {};
    for (final apt in appointments) {
      final day =
          DateTime(apt.startTime.year, apt.startTime.month, apt.startTime.day);
      busyLevels[day] = (busyLevels[day] ?? 0) + 1;
    }
    // Normalize to 0.0-1.0 scale
    return busyLevels
        .map((day, count) => MapEntry(day, _getBusyLevel(count.toInt())));
  });
});

double _getBusyLevel(int appointmentCount) {
  if (appointmentCount == 0) return 0.0;
  if (appointmentCount <= 2) return 0.3;
  if (appointmentCount <= 4) return 0.6;
  return 0.9;
}

Color _getBusyColor(double level, ColorScheme colors) {
  if (level == 0) return colors.surfaceContainerHigh;
  if (level < 0.4) return colors.primaryContainer.withValues(alpha: 0.55);
  if (level < 0.7) return colors.primaryContainer;
  return colors.primary;
}

final calendarAppointmentServicesProvider =
    StreamProvider.family<List<AppointmentService>, int?>((ref, appointmentId) {
  if (appointmentId == null) return Stream.value(const <AppointmentService>[]);
  final db = ref.watch(homeHiveProvider);
  return db.watchAppointmentServicesForAppointment(appointmentId);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(homeHiveProvider);
    final institutionId = ref.watch(authSessionProvider)?.institutionId;
    final busyDaysAsync = ref.watch(calendarBusyDaysProvider);
    final colors = Theme.of(context).colorScheme;
    ref.watch(servicesProvider);
    ref.watch(serviceStationsProvider);
    ref.watch(recentCustomersProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendar Widget
              Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: busyDaysAsync.when(
                  data: (busyDays) => TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        final dayKey =
                            DateTime(date.year, date.month, date.day);
                        final level = busyDays[dayKey] ?? 0.0;
                        if (level == 0) return null;
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _getBusyColor(level, colors),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: AppTypography.bodyLarge.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: AppTypography.bodyLarge.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      defaultTextStyle: AppTypography.bodyMedium.copyWith(
                        color: colors.onSurface,
                      ),
                      weekendTextStyle: AppTypography.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      outsideTextStyle: AppTypography.bodyMedium.copyWith(
                        color: colors.outline,
                      ),
                      markerDecoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerSize: 6,
                      markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      formatButtonTextStyle: AppTypography.labelMedium.copyWith(
                        color: colors.primary,
                      ),
                      titleTextStyle: AppTypography.titleLarge.copyWith(
                        color: colors.onSurface,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: colors.onSurface,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: colors.onSurface,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: AppTypography.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      weekendStyle: AppTypography.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),

              // Selected Day Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDay != null
                          ? DateFormat('EEEE, MMM d').format(_selectedDay!)
                          : 'Select a day',
                      style: AppTypography.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDay = DateTime.now();
                          _focusedDay = DateTime.now();
                        });
                      },
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text('view Today'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Appointments List
              if (_selectedDay != null)
                StreamBuilder<List<Appointment>>(
                  stream: institutionId == null
                      ? Stream.value(const <Appointment>[])
                      : db.watchAppointmentsForDateForInstitution(
                          _selectedDay!,
                          institutionId,
                        ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final appointments = snapshot.data ?? [];

                    if (appointments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 48,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No appointments for this day',
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: appointments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        final lineItems = ref
                                .watch(calendarAppointmentServicesProvider(
                                  appointment.id,
                                ))
                                .value ??
                            const <AppointmentService>[];
                        final services = _resolveServices(
                          db,
                          appointment,
                          lineItems,
                        );
                        final customer = appointment.customerId == null
                            ? null
                            : db.getCustomerById(appointment.customerId!);
                        final station = appointment.stationId == null
                            ? null
                            : db.getServiceStationById(appointment.stationId!);

                        return AppointmentTile(
                          appointment: appointment,
                          customerName: customer?.name ?? '',
                          services: services,
                          totalDurationMinutes: _resolveTotalDuration(
                            appointment,
                            services,
                          ),
                          locationName: station?.name ?? '',
                          onTap: appointment.id != null
                              ? () {
                                  context.pushNamed(
                                    'appointment-detail',
                                    pathParameters: {
                                      'id': appointment.id.toString()
                                    },
                                  );
                                }
                              : null,
                        );
                      },
                    );
                  },
                )
              else
                const Center(
                  child: Text('Select a day to view appointments'),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Second FAB - Full Hourly View
          FloatingActionButton.small(
            heroTag: 'hourly_view',
            onPressed: () {
              final dateStr = _selectedDay != null
                  ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
                  : null;
              context.pushNamed(
                'full-calendar',
                queryParameters: dateStr != null ? {'date': dateStr} : {},
              );
            },
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.schedule_rounded,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Primary FAB - New Booking
          FloatingActionButton(
            heroTag: 'new_booking',
            onPressed: () {
              final dateStr = _selectedDay != null
                  ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
                  : null;
              context.pushNamed(
                'booking',
                queryParameters: dateStr != null ? {'date': dateStr} : {},
              );
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

List<AppointmentTileService> _resolveServices(
  HiveService db,
  Appointment appointment,
  List<AppointmentService> lineItems,
) {
  if (lineItems.isNotEmpty) {
    return lineItems.map((lineItem) {
      final service = lineItem.serviceId == null
          ? null
          : db.getServiceById(lineItem.serviceId!);
      return AppointmentTileService(
        name: service?.title ?? 'Unknown',
        durationMinutes:
            lineItem.durationOverride ?? service?.defaultDurationMinutes ?? 0,
        colorValue: service?.colorValue,
      );
    }).toList(growable: false);
  }

  final service = appointment.serviceId == null
      ? null
      : db.getServiceById(appointment.serviceId!);
  if (service == null) return const <AppointmentTileService>[];

  return <AppointmentTileService>[
    AppointmentTileService(
      name: service.title,
      durationMinutes:
          appointment.endTime.difference(appointment.startTime).inMinutes,
      colorValue: service.colorValue,
    ),
  ];
}

int _resolveTotalDuration(
  Appointment appointment,
  List<AppointmentTileService> services,
) {
  final linkedDuration = services.fold<int>(
    0,
    (total, service) => total + service.durationMinutes,
  );
  if (linkedDuration > 0) return linkedDuration;

  final appointmentDuration =
      appointment.endTime.difference(appointment.startTime).inMinutes;
  return appointmentDuration < 0 ? 0 : appointmentDuration;
}

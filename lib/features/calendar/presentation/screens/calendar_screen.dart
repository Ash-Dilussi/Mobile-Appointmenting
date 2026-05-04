import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../home/presentation/providers/home_provider.dart';

// Provider that maps each day to a busy level (0.0-1.0) based on appointment count
final calendarBusyDaysProvider = StreamProvider<Map<DateTime, double>>((ref) {
  final db = ref.watch(homeHiveProvider);
  return db.watchAllAppointments().map((appointments) {
    final Map<DateTime, double> busyLevels = {};
    for (final apt in appointments) {
      final day = DateTime(apt.startTime.year, apt.startTime.month, apt.startTime.day);
      busyLevels[day] = (busyLevels[day] ?? 0) + 1;
    }
    // Normalize to 0.0-1.0 scale
    return busyLevels.map((day, count) => MapEntry(day, _getBusyLevel(count.toInt())));
  });
});

double _getBusyLevel(int appointmentCount) {
  if (appointmentCount == 0) return 0.0;
  if (appointmentCount <= 2) return 0.3;
  if (appointmentCount <= 4) return 0.6;
  return 0.9;
}

Color _getBusyColor(double level) {
  if (level == 0) return AppColors.surfaceContainerHigh;
  if (level < 0.4) return AppColors.primaryFixedDim;
  if (level < 0.7) return AppColors.primaryContainer;
  return AppColors.primary;
}

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
    final busyDaysAsync = ref.watch(calendarBusyDaysProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Calendar Widget
          Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
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
                    final dayKey = DateTime(date.year, date.month, date.day);
                    final level = busyDays[dayKey] ?? 0.0;
                    if (level == 0) return null;
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getBusyColor(level),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  defaultTextStyle: AppTypography.bodyMedium,
                  weekendTextStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.secondary,
                  ),
                  outsideTextStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.outline,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
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
                    color: AppColors.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  formatButtonTextStyle: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                  titleTextStyle: AppTypography.titleLarge,
                  leftChevronIcon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.onSurface,
                  ),
                  rightChevronIcon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurface,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTypography.labelMedium.copyWith(
                    color: AppColors.secondary,
                  ),
                  weekendStyle: AppTypography.labelMedium.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
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
                  style: AppTypography.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDay = DateTime.now();
                      _focusedDay = DateTime.now();
                    });
                  },
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Today'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Appointments List
          Expanded(
            child: _selectedDay != null
                ? StreamBuilder<List<Appointment>>(
                    stream: db.watchAppointmentsForDate(_selectedDay!),
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
                                color: AppColors.secondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No appointments for this day',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: appointments[index].id != null
                                ? () {
                                    context.goNamed(
                                      'appointment-detail',
                                      pathParameters: {'id': appointments[index].id.toString()},
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            child: _CalendarAppointmentCard(
                              appointment: appointments[index],
                            ),
                          );
                        },
                      );
                    },
                  )
                : const Center(
                    child: Text('Select a day to view appointments'),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
    );
  }
}

class _CalendarAppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _CalendarAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    Color statusColor;
    switch (appointment.status) {
      case 'confirmed':
        statusColor = AppColors.success;
        break;
      case 'ongoing':
        statusColor = AppColors.ongoing;
        break;
      case 'done':
        statusColor = AppColors.secondary;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeFormat.format(appointment.startTime),
                style: AppTypography.titleMedium,
              ),
              Text(
                '${timeFormat.format(appointment.startTime)} - ${timeFormat.format(appointment.endTime)}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              appointment.status.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

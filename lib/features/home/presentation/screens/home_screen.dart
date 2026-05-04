import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final today = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d');

    // Extract user name from email
    final userName = authState.user?.email.split('@').first ?? 'Receptionist';
    final userInitials = userName.isNotEmpty ? userName[0].toUpperCase() : 'R';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with logo, avatar, greeting and bell
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Row(
                  children: [
                    // App Logo
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        Icons.book_online,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // User Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $userName',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            dateFormat.format(today),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification Bell
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Upcoming Bookings - Stacked cards with glassmorphism
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: _UpcomingBookingsList(),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Availability Summary for Next Two Weeks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Availability',
                              style: AppTypography.titleMedium,
                            ),
                            Text(
                              'Next 2 weeks',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _AvailabilityGrid(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Recent Clients Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Clients',
                              style: AppTypography.titleMedium,
                            ),
                            TextButton(
                              onPressed: () => context.goNamed('customers'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RecentClientsRow(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingBookingsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAppointments = ref.watch(upcomingAppointmentsProvider);

    return SizedBox(
      height: 200,
      child: upcomingAppointments.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return Center(
              child: _EmptyCarouselCard(),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < appointments.length - 1 ? AppSpacing.md : 0,
                ),
                child: _BookingSquareCard(appointment: appointments[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: _EmptyCarouselCard()),
      ),
    );
  }
}

class _BookingSquareCard extends ConsumerWidget {
  final Appointment appointment;

  const _BookingSquareCard({required this.appointment});

  Color _getPaleTimeBasedColor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) {
      // Morning - pale blue
      return Color(0xFFB3D9FF);
    } else if (hour >= 11 && hour < 17) {
      // Noon - pale orange
      return Color(0xFFFFCC80);
    } else if (hour >= 17 && hour < 21) {
      // Evening - pale purple
      return Color(0xFFB39DDB);
    } else {
      // Night - pale slate
      return Color(0xFF78909C);
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'upcoming':
        return 'Upcoming';
      case 'confirmed':
        return 'Confirmed';
      case 'ongoing':
        return 'In Progress';
      case 'done':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Scheduled';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEE, MMM d');
    final paleColor = _getPaleTimeBasedColor(appointment.startTime);

    // Look up customer and service from Hive
    final hiveService = ref.watch(homeHiveProvider);
    final customer = hiveService.getCustomerById(appointment.customerId ?? -1);
    final service = appointment.serviceId != null
        ? hiveService.getServiceById(appointment.serviceId!)
        : null;

    final customerName = customer?.name ?? 'Client';
    final serviceName = service?.title ?? 'Appointment';
    final statusText = _getStatusText(appointment.status);

    return InkWell(
      onTap: appointment.id != null
          ? () {
              context.goNamed(
                'appointment-detail',
                pathParameters: {'id': appointment.id.toString()},
              );
            }
          : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Status badge and chevron
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 10,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            // Time block - card-in-card style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: paleColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    timeFormat.format(appointment.startTime),
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    dateFormat.format(appointment.startTime),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Customer name
            Text(
              customerName,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Service name
            Text(
              serviceName,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCarouselCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.event_available_outlined,
              color: AppColors.primaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No upcoming bookings',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap + to create one',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = <List<DateTime>>[];

    // Generate 14 days (2 weeks)
    for (int week = 0; week < 2; week++) {
      final weekDays = <DateTime>[];
      for (int day = 0; day < 7; day++) {
        weekDays.add(now.add(Duration(days: week * 7 + day)));
      }
      weeks.add(weekDays);
    }

    // Simulate availability data (in real app, this would come from a provider)
    final availabilityLevels = [
      [0.8, 0.3, 0.5, 0.9, 0.2, 0.0, 0.1], // Week 1
      [0.6, 0.4, 0.7, 0.3, 0.5, 0.0, 0.2], // Week 2
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          // Availability grid
          ...weeks.asMap().entries.map((weekEntry) {
            final weekIndex = weekEntry.key;
            final weekDays = weekEntry.value;
            final levels = availabilityLevels[weekIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      weekIndex == 0 ? 'This Week' : 'Next Week',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Row(
                    children: weekDays.asMap().entries.map((dayEntry) {
                      final dayIndex = dayEntry.key;
                      final date = dayEntry.value;
                      final level = levels[dayIndex];
                      final isToday = date.day == now.day &&
                          date.month == now.month &&
                          date.year == now.year;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          child: _AvailabilityCell(
                            level: level,
                            isToday: isToday,
                            date: date,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.primaryFixedDim, label: 'Low'),
              const SizedBox(width: AppSpacing.lg),
              _LegendItem(color: AppColors.primaryContainer, label: 'Medium'),
              const SizedBox(width: AppSpacing.lg),
              _LegendItem(color: AppColors.primary, label: 'High'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCell extends StatelessWidget {
  final double level;
  final bool isToday;
  final DateTime date;

  const _AvailabilityCell({
    required this.level,
    required this.isToday,
    required this.date,
  });

  String _getDayAbbreviation() {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    Color cellColor;
    if (level == 0) {
      cellColor = AppColors.surfaceContainerHigh;
    } else if (level < 0.4) {
      cellColor = AppColors.primaryFixedDim;
    } else if (level < 0.7) {
      cellColor = AppColors.primaryContainer;
    } else {
      cellColor = AppColors.primary;
    }

    return Column(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(9999),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              _getDayAbbreviation(),
              style: AppTypography.labelSmall.copyWith(
                color: level > 0.5 ? Colors.white : AppColors.onPrimaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date.day.toString(),
          style: AppTypography.labelSmall.copyWith(
            color: isToday ? AppColors.primary : AppColors.secondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall,
        ),
      ],
    );
  }
}

class _RecentClientsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentCustomers = ref.watch(recentCustomersProvider);

    return recentCustomers.when(
      data: (customers) {
        if (customers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _EmptyClientsCard(),
          );
        }
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < customers.length - 1 ? AppSpacing.md : 0,
                ),
                child: _ClientCard(customer: customers[index]),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _EmptyClientsCard(),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Customer customer;

  const _ClientCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final initials = customer.name.isNotEmpty
        ? customer.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return InkWell(
      onTap: () {
        context.goNamed(
          'customer-profile',
          pathParameters: {'id': customer.id.toString()},
        );
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.toUpperCase(),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              customer.name,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              customer.phoneNumber,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.secondary,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClientsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.people_outline,
              color: AppColors.onSecondaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No clients yet',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Customers will appear here',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
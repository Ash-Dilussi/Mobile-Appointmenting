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
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    // Extract user name from email
    final userName = authState.user?.email.split('@').first ?? 'Receptionist';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user name and date
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dateFormat.format(today),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Upcoming Bookings Carousel
              _UpcomingBookingsCarousel(),

              const SizedBox(height: AppSpacing.xxl),

              // Availability Summary for Next Two Weeks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Text(
                  'Availability (Next 2 Weeks)',
                  style: AppTypography.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _AvailabilityGrid(),

              const SizedBox(height: AppSpacing.xxl),

              // Recent Clients Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingBookingsCarousel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAppointments = ref.watch(upcomingAppointmentsProvider);

    return SizedBox(
      height: 140,
      child: upcomingAppointments.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return Center(
              child: _EmptyCarouselCard(),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < appointments.length - 1 ? AppSpacing.md : 0,
                ),
                child: _BookingCarouselCard(appointment: appointments[index]),
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

class _BookingCarouselCard extends StatelessWidget {
  final Appointment appointment;

  const _BookingCarouselCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              appointment.status.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeFormat.format(appointment.startTime),
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                dateFormat.format(appointment.startTime),
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          // Week day headers
          Row(
            children: [
              const SizedBox(width: 40), // Space for "This Week" label
              ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Availability grid
          ...weeks.asMap().entries.map((weekEntry) {
            final weekIndex = weekEntry.key;
            final weekDays = weekEntry.value;
            final levels = availabilityLevels[weekIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      weekIndex == 0 ? 'This Week' : 'Next Week',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  ...weekDays.asMap().entries.map((dayEntry) {
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
                  }),
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
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: level > 0
              ? Center(
                  child: Text(
                    '${(level * 100).round()}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: level > 0.5 ? Colors.white : AppColors.onPrimaryContainer,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: _EmptyClientsCard(),
          );
        }
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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
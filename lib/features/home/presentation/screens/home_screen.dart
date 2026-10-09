import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/release_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/app_surface_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static final _headerDateFormat = DateFormat('EEEE, MMMM d');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateProvider);
    final session = ref.watch(authSessionProvider);
    final today = DateTime.now();

    // Extract user name from email
    final userName = authState.user?.email.split('@').first ?? 'Receptionist';
    final userInitials = userName.isNotEmpty ? userName[0].toUpperCase() : 'R';

    return Scaffold(
      backgroundColor: colors.surface,
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
                        color: colors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        Icons.book_online,
                        color: colors.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // User Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: AppTypography.titleMedium.copyWith(
                            color: colors.onPrimaryContainer,
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
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            _headerDateFormat.format(today),
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ReleaseScope.developmentOnlyDestinationsEnabled)
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => context.pushNamed(
                          'coming-soon',
                          queryParameters: const {'feature': 'Notifications'},
                        ),
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              if (session != null && !session.hasInstitution)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: _BusinessSetupBanner(),
                ),

              if (session?.shouldPromptPasswordChange == true)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.screenPadding,
                    right: AppSpacing.screenPadding,
                    top: AppSpacing.md,
                  ),
                  child: _PasswordChangePrompt(),
                ),

              // Upcoming Bookings - Stacked cards with glassmorphism
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: _UpcomingBookingsList(),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Availability Summary for Next Two Weeks
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Availability',
                      subtitle: 'Next 2 weeks',
                      actionLabel: 'View Calendar',
                      onAction: () => context.goNamed('calendar'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: _AvailabilityGrid(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Recent Clients Row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Recent Clients',
                      actionLabel: 'See All',
                      onAction: () => context.goNamed('customers'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RecentClientsRow(),
                  ],
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

class _BusinessSetupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Business setup required',
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.business_outlined, color: colors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up your business to get started',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose a solo or team setup to manage appointments, services, and staff.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.pushNamed('business-setup'),
                    child: const Text('Set up your business'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordChangePrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change your temporary password',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'For your account security, you can set a new password now or later from Settings.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: () => context.pushNamed('change-password'),
                child: const Text('Change password'),
              ),
              TextButton(
                onPressed: () => ref
                    .read(authNotifierProvider.notifier)
                    .acknowledgePasswordChangePrompt(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingBookingsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAppointments = ref.watch(upcomingAppointmentsProvider);
    final hiveService = ref.watch(homeHiveProvider);
    ref.watch(servicesProvider);

    return SizedBox(
      // Keep breathing room inside the carousel so card shadows can paint
      // above and below each card without being cut off by the viewport.
      height: 216,
      child: upcomingAppointments.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return Center(
              child: _EmptyCarouselCard(),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final apt = appointments[index];
              final customer =
                  hiveService.getCustomerById(apt.customerId ?? -1);
              final service = apt.serviceId != null
                  ? hiveService.getServiceById(apt.serviceId!)
                  : null;
              return Padding(
                padding: EdgeInsets.only(
                  right: index < appointments.length - 1 ? AppSpacing.lg : 0,
                ),
                child: _BookingSquareCard(
                  appointment: apt,
                  customerName: customer?.name ?? 'Client',
                  serviceName: service?.title ?? 'Appointment',
                  serviceColorValue: service?.colorValue,
                ),
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

class _BookingSquareCard extends StatelessWidget {
  final Appointment appointment;
  final String customerName;
  final String serviceName;
  final int? serviceColorValue;

  const _BookingSquareCard({
    required this.appointment,
    required this.customerName,
    required this.serviceName,
    this.serviceColorValue,
  });

  static final _timeFormat = DateFormat('HH:mm');
  static final _dateFormat = DateFormat('EEE, MMM d');

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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final serviceColor = ServiceColorPalette.resolve(serviceColorValue).color;
    final statusText = _getStatusText(appointment.status);

    return InkWell(
      onTap: appointment.id != null
          ? () {
              context.pushNamed(
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
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppShadows.card(colorScheme.primaryContainer),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The service badge keeps the appointment visually tied to its
            // service type across every appointment view.
            Row(
              children: [
                Expanded(
                  child: ServiceBadge(
                    label: serviceName,
                    colorValue: serviceColorValue,
                    compact: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            // Time block - card-in-card style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: serviceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    _timeFormat.format(appointment.startTime),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    _dateFormat.format(appointment.startTime),
                    style: AppTypography.labelSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
            // Appointment status remains text, so meaning never relies on
            // the service color alone.
            Text(
              statusText,
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.event_available_outlined,
              color: colors.onPrimaryContainer,
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
    final colors = Theme.of(context).colorScheme;
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
                        color: colors.onSurfaceVariant,
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
              _LegendItem(color: colors.primaryFixedDim, label: 'Low'),
              const SizedBox(width: AppSpacing.lg),
              _LegendItem(color: colors.primaryContainer, label: 'Medium'),
              const SizedBox(width: AppSpacing.lg),
              _LegendItem(color: colors.primary, label: 'High'),
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
    final colors = Theme.of(context).colorScheme;
    Color cellColor;
    Color cellForeground;
    if (level == 0) {
      cellColor = colors.surfaceContainerHigh;
      cellForeground = colors.onSurfaceVariant;
    } else if (level < 0.4) {
      cellColor = colors.primaryFixedDim;
      cellForeground = colors.onPrimaryFixedVariant;
    } else if (level < 0.7) {
      cellColor = colors.primaryContainer;
      cellForeground = colors.onPrimaryContainer;
    } else {
      cellColor = colors.primary;
      cellForeground = colors.onPrimary;
    }

    return Column(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(9999),
            border:
                isToday ? Border.all(color: colors.primary, width: 2) : null,
          ),
          child: Center(
            child: Text(
              _getDayAbbreviation(),
              style: AppTypography.labelSmall.copyWith(
                color: cellForeground,
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
            color: isToday ? colors.primary : colors.onSurfaceVariant,
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
          return _EmptyClientsCard();
        }
        return SizedBox(
          height: 148,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < customers.length - 1 ? AppSpacing.lg : 0,
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
      error: (_, __) => _EmptyClientsCard(),
    );
  }
}

class _ClientCard extends StatefulWidget {
  final Customer customer;

  const _ClientCard({required this.customer});

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  static const _pressDuration = Duration(milliseconds: 120);
  static const _pressedScale = 0.97;

  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final customer = widget.customer;
    final trimmedName = customer.name.trim();
    final displayName = trimmedName.isEmpty ? 'Unnamed customer' : trimmedName;
    final phone = customer.phoneNumber.trim();
    final customerId = customer.id;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    void openProfile() {
      if (customerId == null) return;
      context.goNamed(
        'customer-profile',
        pathParameters: {'id': customerId.toString()},
      );
    }

    return Semantics(
      button: customerId != null,
      enabled: customerId != null,
      label: customerId == null ? displayName : 'Open $displayName profile',
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: customerId == null ? null : openProfile,
        onTapDown: customerId == null ? null : (_) => _setPressed(true),
        onTapUp: customerId == null ? null : (_) => _setPressed(false),
        onTapCancel: customerId == null ? null : () => _setPressed(false),
        child: AnimatedScale(
          scale: _isPressed && !reduceMotion ? _pressedScale : 1,
          duration: reduceMotion ? Duration.zero : _pressDuration,
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 132,
            child: AppSurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        trimmedName.isEmpty
                            ? '?'
                            : trimmedName[0].toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    displayName,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      phone,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyClientsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.people_outline,
              color: colors.onSecondaryContainer,
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

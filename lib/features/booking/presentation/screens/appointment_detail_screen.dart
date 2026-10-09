import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/appointment.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/appointment_tile.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../call_history/application/app_call_service.dart';
import '../widgets/appointment_note_card.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final int appointmentId;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final db = ref.watch(homeHiveProvider);
    final appointment = db.getAppointmentById(widget.appointmentId);

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed('home');
              }
            },
          ),
        ),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    // Fetch related data
    final customer = appointment.customerId != null
        ? db.getCustomerById(appointment.customerId!)
        : null;
    final service = appointment.serviceId != null
        ? db.getServiceById(appointment.serviceId!)
        : null;
    final station = appointment.stationId != null
        ? db.getServiceStationById(appointment.stationId!)
        : null;
    final customerName = customer?.name.trim() ?? '';
    final customerPhone = customer?.phoneNumber.trim() ?? '';
    final customerEmail = customer?.email?.trim() ?? '';
    final customerId = customer?.id;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
        ),
        title: const Text('Appointment Details'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await context.pushNamed<bool>(
                'booking-edit',
                pathParameters: {'id': widget.appointmentId.toString()},
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: AppBadge(
                presentation: appointmentStatusPresentation(
                  appointment.status,
                  colors,
                ),
                showDot: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _StatusActionsCard(
              currentStatus: appointment.status,
              onStatusSelected: (status) => _updateStatus(
                appointment: appointment,
                status: status,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Customer Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.person,
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName.isEmpty ? 'Unknown Customer' : customerName,
                    style: AppTypography.titleLarge,
                  ),
                  if (customer != null) ...[
                    if (customerPhone.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.phone,
                        text: customerPhone,
                      ),
                    ],
                    if (customerEmail.isNotEmpty)
                      _InfoRow(
                        icon: Icons.email,
                        text: customerEmail,
                      ),
                    if (customerId != null && customerPhone.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => _handleCall(
                          customerId: customerId,
                          phoneNumber: customerPhone,
                        ),
                        icon: const Icon(Icons.call),
                        label: const Text('Call Customer'),
                      ),
                    ],
                    if (customerId != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () {
                          context.goNamed(
                            'customer-profile',
                            pathParameters: {'id': customerId.toString()},
                          );
                        },
                        child: Text(
                          'View Customer Profile',
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Service Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.spa,
              title: 'Service',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ServiceBadge(
                    label: service?.title ?? 'No Service Assigned',
                    colorValue: service?.colorValue,
                  ),
                  if (service != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.schedule,
                            text: '${service.defaultDurationMinutes} minutes',
                          ),
                        ),
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.attach_money,
                            text: '\$${service.cost.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Date & Time Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.calendar_today,
              title: 'Date & Time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy')
                        .format(appointment.startTime),
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    DateFormat('h:mm a').format(appointment.startTime),
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      'Duration: ${appointment.endTime.difference(appointment.startTime).inMinutes} minutes',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Station Section - Floating Pebble Card (if station exists)
            if (station != null) ...[
              _PebbleCard(
                icon: Icons.location_on,
                title: 'Station',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        Icons.chair,
                        color: colors.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      station.name,
                      style: AppTypography.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Structured appointment notes are read-only here. Editing remains
            // centralized in BookingScreen's edit flow.
            if (appointment.notes.isNotEmpty) ...[
              _PebbleCard(
                icon: Icons.notes,
                title: 'Notes',
                child: Column(
                  children: [
                    for (var index = 0;
                        index < appointment.notes.length;
                        index++) ...[
                      AppointmentNoteCard(note: appointment.notes[index]),
                      if (index < appointment.notes.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Created/Updated Info
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                'Created ${_formatDate(appointment.createdAt)}',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCall({
    required int customerId,
    required String phoneNumber,
  }) async {
    final result = await ref.read(appCallServiceProvider).initiateCustomerCall(
          customerId: customerId,
          phoneNumber: phoneNumber,
        );
    final message = result.failureMessage;
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _updateStatus({
    required Appointment appointment,
    required String status,
  }) async {
    if (appointment.status == status) return;

    final label = switch (status) {
      Appointment.statusDone => 'complete this appointment',
      Appointment.statusCancelled => 'cancel this appointment',
      Appointment.statusNoShow => 'mark this appointment as a no-show',
      _ => 'change this appointment',
    };
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Update appointment status?'),
            content: Text('Are you sure you want to $label?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep current status'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Update status'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    appointment
      ..status = status
      ..updatedAt = DateTime.now()
      ..synced = false;
    final updated = await ref
        .read(homeHiveProvider)
        .updateAppointment(widget.appointmentId, appointment);
    if (!mounted) return;
    if (updated) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? 'Appointment status updated.'
              : 'Could not update the appointment status.',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

class _StatusActionsCard extends StatelessWidget {
  const _StatusActionsCard({
    required this.currentStatus,
    required this.onStatusSelected,
  });

  final String currentStatus;
  final ValueChanged<String> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTerminal = currentStatus == Appointment.statusDone ||
        currentStatus == Appointment.statusCancelled ||
        currentStatus == Appointment.statusNoShow;

    return _PebbleCard(
      icon: Icons.fact_check_outlined,
      title: 'Status actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isTerminal
                ? 'This appointment has a final status. You can still correct it below.'
                : 'Record the outcome so operational reports remain accurate.',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusButton(
                label: 'Completed',
                icon: Icons.check_circle_outline,
                selected: currentStatus == Appointment.statusDone,
                onPressed: () => onStatusSelected(Appointment.statusDone),
              ),
              _StatusButton(
                label: 'No-show',
                icon: Icons.person_off_outlined,
                selected: currentStatus == Appointment.statusNoShow,
                onPressed: () => onStatusSelected(Appointment.statusNoShow),
              ),
              _StatusButton(
                label: 'Cancelled',
                icon: Icons.cancel_outlined,
                selected: currentStatus == Appointment.statusCancelled,
                onPressed: () => onStatusSelected(Appointment.statusCancelled),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label appointment status',
      child: SizedBox(
        height: 48,
        child: selected
            ? FilledButton.icon(
                onPressed: null,
                icon: Icon(icon),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              ),
      ),
    );
  }
}

class _PebbleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PebbleCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: AppShadows.overlay(colors.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: colors.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium,
          ),
        ),
      ],
    );
  }
}

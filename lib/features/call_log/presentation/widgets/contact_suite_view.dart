import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/call_log_entry.dart';
import '../../providers/call_log_providers.dart';
import 'appointment_history_tile.dart';

class ContactSuiteView extends ConsumerWidget {
  final CallLogEntry entry;

  const ContactSuiteView({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If customerId is null, show unknown number view
    if (entry.customerId == null) {
      return _UnknownNumberView(entry: entry);
    }

    // Otherwise show the full contact suite
    return _KnownContactView(entry: entry);
  }
}

class _KnownContactView extends ConsumerWidget {
  final CallLogEntry entry;

  const _KnownContactView({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactData = ref.watch(contactSuiteProvider(entry.customerId));

    return DraggableScrollableSheet(
      minChildSize: 0.45,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              _DragHandle(),
              // Scrollable content
              Expanded(
                child: contactData.when(
                  data: (data) {
                    if (data == null) {
                      return const Center(
                        child: Text('Customer not found'),
                      );
                    }
                    return _ContactContent(
                      data: data,
                      entry: entry,
                      scrollController: scrollController,
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactContent extends StatelessWidget {
  final dynamic data; // ContactSuiteData
  final CallLogEntry entry;
  final ScrollController scrollController;

  const _ContactContent({
    required this.data,
    required this.entry,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final customer = data.customer;
    final upcomingAppointments = data.upcomingAppointments;
    final pastAppointments = data.pastAppointments;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Header Section
        _ContactHeader(
          customer: customer,
          phoneNumber: entry.phoneNumber,
        ),

        const Divider(height: AppSpacing.xl),

        // Notes Section
        _NotesSection(
          notes: customer.notes,
          customerId: customer.id,
        ),

        const Divider(height: AppSpacing.xl),

        // Appointment History Section
        _AppointmentHistorySection(
          upcomingAppointments: upcomingAppointments,
          pastAppointments: pastAppointments,
        ),
      ],
    );
  }
}

class _ContactHeader extends StatelessWidget {
  final dynamic customer;
  final String phoneNumber;

  const _ContactHeader({
    required this.customer,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    // Get initials for avatar
    final name = customer.name ?? 'Unknown';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            initials.toUpperCase(),
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Name
        Text(
          name,
          style: AppTypography.titleLarge,
        ),

        const SizedBox(height: AppSpacing.xs),

        // Phone number (tappable)
        InkWell(
          onTap: () => _launchPhone(phoneNumber),
          child: Text(
            phoneNumber,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Action chips
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Call button
            ActionChip(
              avatar: const Icon(Icons.phone, size: 18),
              label: const Text('Call'),
              onPressed: () => _launchPhone(phoneNumber),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Book Now button
            ActionChip(
              avatar: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Book Now'),
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(
                  'booking',
                  queryParameters: {'customerId': customer.id.toString()},
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _NotesSection extends StatelessWidget {
  final String? notes;
  final int? customerId;

  const _NotesSection({
    required this.notes,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notes',
              style: AppTypography.titleMedium,
            ),
            if (customerId != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  context.pushNamed(
                    'edit-customer',
                    pathParameters: {'id': customerId.toString()},
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          notes ?? 'No notes',
          style: AppTypography.bodyMedium.copyWith(
            color: notes != null ? null : AppColors.secondary,
          ),
          maxLines: 4,
          softWrap: true,
        ),
      ],
    );
  }
}

class _AppointmentHistorySection extends StatelessWidget {
  final List<dynamic> upcomingAppointments;
  final List<dynamic> pastAppointments;

  const _AppointmentHistorySection({
    required this.upcomingAppointments,
    required this.pastAppointments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appointment History',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (upcomingAppointments.isEmpty && pastAppointments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'No appointments yet',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ),

        // Upcoming appointments
        if (upcomingAppointments.isNotEmpty) ...[
          _SectionHeader(
            title: 'Upcoming',
            color: AppColors.primary,
          ),
          ...upcomingAppointments.map(
            (apt) => AppointmentHistoryTile(appointment: apt),
          ),
        ],

        // Past appointments
        if (pastAppointments.isNotEmpty) ...[
          _SectionHeader(
            title: 'Past',
            color: AppColors.secondary,
          ),
          ...pastAppointments.map(
            (apt) => AppointmentHistoryTile(appointment: apt),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnknownNumberView extends StatelessWidget {
  final CallLogEntry entry;

  const _UnknownNumberView({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          _DragHandle(),

          const SizedBox(height: AppSpacing.xl),

          // Icon
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: AppColors.secondary.withValues(alpha: 0.5),
          ),

          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            'Unknown Number',
            style: AppTypography.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Phone number
          SelectableText(
            entry.phoneNumber,
            style: AppTypography.bodyLarge.copyWith(
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Save as new customer button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(
                  'add-customer',
                  queryParameters: {'phone': entry.phoneNumber},
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Save as New Customer'),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Call this number button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri(scheme: 'tel', path: entry.phoneNumber);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text('Call This Number'),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

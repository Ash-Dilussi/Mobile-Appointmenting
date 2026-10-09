import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/collections/collections.dart';
import '../../../../core/database/hive_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/age_utils.dart';
import '../../../../shared/widgets/appointment_tile.dart';
import '../../../call_history/application/app_call_service.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../widgets/customer_note_card.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final int customerId;

  const CustomerProfileScreen({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final customer = db.getCustomerById(customerId);
    final colors = Theme.of(context).colorScheme;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final trimmedName = customer.name.trim();
    final displayName = trimmedName.isEmpty ? 'Unnamed customer' : trimmedName;
    final phone = customer.phoneNumber.trim();
    final email = customer.email?.trim() ?? '';
    final address = customer.address?.trim() ?? '';
    final city = customer.city?.trim() ?? '';
    final createdAt = customer.createdAt;
    final dob = customer.dob;
    final hasContactInformation = phone.isNotEmpty ||
        email.isNotEmpty ||
        address.isNotEmpty ||
        city.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('customers'),
        ),
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.goNamed(
                'edit-customer',
                pathParameters: {'id': customerId.toString()},
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        trimmedName.isNotEmpty
                            ? trimmedName[0].toUpperCase()
                            : '?',
                        style: AppTypography.displaySmall.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    displayName,
                    style: AppTypography.headlineMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (createdAt != null)
                    Text(
                      'Customer since ${DateFormat('MMM yyyy').format(createdAt)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Contact Info Card
            _SectionCard(
              title: 'Contact Information',
              children: [
                if (phone.isNotEmpty)
                  _InfoRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: phone,
                  ),
                if (email.isNotEmpty)
                  _InfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: email,
                  ),
                if (address.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: address,
                  ),
                if (city.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: city,
                  ),
                if (dob != null)
                  _InfoRow(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: '${currentAge(dob)} years',
                  ),
                if (!hasContactInformation && dob == null)
                  Text(
                    'No contact information available',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Notes Card
            if (customer.notes.isNotEmpty)
              _SectionCard(
                title: 'Notes',
                children: [
                  for (var index = 0;
                      index < customer.notes.length;
                      index++) ...[
                    CustomerNoteCard(note: customer.notes[index]),
                    if (index < customer.notes.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),

            const SizedBox(height: AppSpacing.lg),

            // Appointment History
            Text(
              'Appointment History',
              style: AppTypography.titleMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _AppointmentHistory(
              customerId: customerId,
              customerName: displayName,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        'booking',
                        queryParameters: {
                          'customerId': customerId.toString(),
                          if (phone.isNotEmpty) 'phone': phone,
                        },
                      );
                    },
                    icon: const Icon(Icons.event),
                    label: const Text('Book Appointment'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: phone.isEmpty
                        ? null
                        : () => _handleCall(
                              context,
                              ref,
                              customerId,
                              phone,
                            ),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCall(
    BuildContext context,
    WidgetRef ref,
    int customerId,
    String phoneNumber,
  ) async {
    final result = await ref.read(appCallServiceProvider).initiateCustomerCall(
          customerId: customerId,
          phoneNumber: phoneNumber,
        );
    final message = result.failureMessage;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentHistory extends ConsumerWidget {
  final int customerId;
  final String customerName;

  const _AppointmentHistory({
    required this.customerId,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final db = ref.watch(homeHiveProvider);
    final appointments = db.getAppointmentsForCustomer(customerId);

    if (appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Center(
          child: Text(
            'No appointments yet',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final lineItems = appointment.id == null
            ? const <AppointmentService>[]
            : db.getAppointmentServicesForAppointment(appointment.id!);
        final services = _resolveAppointmentServices(
          db,
          appointment,
          lineItems,
        );
        final station = appointment.stationId == null
            ? null
            : db.getServiceStationById(appointment.stationId!);

        return AppointmentTile(
          appointment: appointment,
          customerName: customerName,
          services: services,
          totalDurationMinutes: _resolveAppointmentDuration(
            appointment,
            services,
          ),
          locationName: station?.name ?? '',
          onTap: appointment.id == null
              ? null
              : () {
                  context.pushNamed(
                    'appointment-detail',
                    pathParameters: {'id': appointment.id.toString()},
                  );
                },
        );
      },
    );
  }
}

List<AppointmentTileService> _resolveAppointmentServices(
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

int _resolveAppointmentDuration(
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

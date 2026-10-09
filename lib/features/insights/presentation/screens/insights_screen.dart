import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/release_scope.dart';
import '../../../../core/database/insights_data.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../providers/insights_provider.dart';

enum _DatePreset { week, month, custom }

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({
    super.key,
    required this.canViewOwnerSections,
  });

  final bool canViewOwnerSections;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  _DatePreset _preset = _DatePreset.month;
  InsightsGrouping _grouping = InsightsGrouping.weekly;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _applyPreset(_DatePreset.month, notify: false);
  }

  void _applyPreset(_DatePreset preset, {bool notify = true}) {
    final now = DateUtils.dateOnly(DateTime.now());
    late DateTime start;
    late DateTime end;
    switch (preset) {
      case _DatePreset.week:
        start = now.subtract(Duration(days: now.weekday - DateTime.monday));
        end = start.add(const Duration(days: 7));
      case _DatePreset.month:
        start = DateTime(now.year, now.month);
        end = DateTime(now.year, now.month + 1);
      case _DatePreset.custom:
        return;
    }
    void update() {
      _preset = preset;
      _start = start;
      _end = end;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _selectCustomRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(today.year - 1, today.month, today.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _start.isBefore(firstDate) ? firstDate : _start,
        end: _end.subtract(const Duration(days: 1)).isAfter(today)
            ? today
            : _end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Choose an Insights date range',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _preset = _DatePreset.custom;
      _start = DateUtils.dateOnly(selected.start);
      _end = DateUtils.dateOnly(selected.end).add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider);
    final institutionId = session?.institutionId;
    if (institutionId == null || institutionId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Text('Connect this account to a business to view Insights.'),
          ),
        ),
      );
    }

    final query = InsightsQuery(
      institutionId: institutionId,
      start: _start,
      end: _end,
      grouping: _grouping,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.lg,
            AppSpacing.screenPadding,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              'Business performance',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${DateFormat.yMMMd().format(_start)} – ${DateFormat.yMMMd().format(_end.subtract(const Duration(days: 1)))}',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Filters(
              preset: _preset,
              grouping: _grouping,
              onPresetSelected: (preset) {
                if (preset == _DatePreset.custom) {
                  _selectCustomRange();
                } else {
                  _applyPreset(preset);
                }
              },
              onGroupingSelected: (grouping) {
                setState(() => _grouping = grouping);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            ref.watch(legacyExclusionInsightsProvider).when(
                  data: (data) => data.recordCount == 0
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          child: _LegacyNotice(count: data.recordCount),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            _AsyncSection<AppointmentInsights>(
              title: 'Appointments',
              subtitle: 'Scheduled outcomes in this period',
              value: ref.watch(appointmentInsightsProvider(query)),
              builder: (data) => _StatGrid(
                items: [
                  _StatItem('Booked', data.booked),
                  _StatItem(
                    'Completed',
                    data.completed,
                    detail:
                        '${data.rate(data.completed.value.toInt()).toStringAsFixed(0)}% rate',
                  ),
                  _StatItem(
                    'Cancelled',
                    data.cancelled,
                    detail:
                        '${data.rate(data.cancelled.value.toInt()).toStringAsFixed(0)}% rate',
                  ),
                  _StatItem(
                    'No-show',
                    data.noShow,
                    detail:
                        '${data.rate(data.noShow.value.toInt()).toStringAsFixed(0)}% rate',
                  ),
                ],
              ),
            ),
            _AsyncSection<CustomerInsights>(
              title: 'Customers',
              subtitle: 'New and returning relationships',
              value: ref.watch(customerInsightsProvider(query)),
              builder: (data) => _StatGrid(
                items: [
                  _StatItem('New', data.newCustomers),
                  _StatItem('Returning', data.returningCustomers),
                  _StatItem(
                    'Repeat visits',
                    InsightMetric(
                      value: data.repeatVisitRate,
                      previousValue: 0,
                    ),
                    valueSuffix: '%',
                    showDelta: false,
                  ),
                ],
              ),
            ),
            _AsyncSection<List<RankedInsight>>(
              title: 'Hot services',
              subtitle: 'Most-booked services',
              value: ref.watch(hotServiceInsightsProvider(query)),
              builder: (data) => _RankedList(
                items: data,
                valueLabel: (value) => '${value.toInt()} bookings',
              ),
            ),
            if (ReleaseScope.callInsightsVerified)
              _AsyncSection<CallInsights>(
                title: 'Calls',
                subtitle: 'Call handling and booking conversion',
                value: ref.watch(callInsightsProvider(query)),
                builder: (data) => _StatGrid(
                  items: [
                    _StatItem('Total', data.total),
                    _StatItem('Answered', data.answered),
                    _StatItem('Missed', data.missed),
                    _StatItem(
                      'Average duration',
                      data.averageDurationSeconds,
                      valueSuffix: ' sec',
                    ),
                    _StatItem(
                      'Conversion',
                      InsightMetric(
                        value: data.conversionRate,
                        previousValue: 0,
                      ),
                      valueSuffix: '%',
                      showDelta: false,
                    ),
                  ],
                ),
              )
            else
              const _UnavailableSection(
                title: 'Calls',
                message:
                    'Call analytics will appear after real-device call ingestion and booking-link verification.',
              ),
            InsightsOwnerSectionBoundary(
              canViewOwnerSections: widget.canViewOwnerSections,
              builder: (context, ownerRef) => Column(
                children: [
                  _AsyncSection<BookedValueInsights>(
                    title: 'Booked service value',
                    subtitle: 'Scheduled value, not collected revenue',
                    value: ownerRef.watch(bookedValueInsightsProvider(query)),
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatGrid(
                          items: [
                            _StatItem(
                              'Total booked value',
                              data.total,
                              valuePrefix: '\$',
                            ),
                            _StatItem(
                              'Average per appointment',
                              data.averagePerAppointment,
                              valuePrefix: '\$',
                            ),
                          ],
                        ),
                        if (data.byService.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _RankedList(
                            items: data.byService,
                            valueLabel: (value) =>
                                '\$${value.toStringAsFixed(2)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (ReleaseScope.staffInsightsVerified)
                    _AsyncSection<StaffInsights>(
                      title: 'Staff performance',
                      subtitle: 'Owner-only operational comparison',
                      value: ownerRef.watch(staffInsightsProvider(query)),
                      builder: (data) => _RankedList(
                        items: data.people,
                        valueLabel: (value) => '${value.toInt()} appointments',
                      ),
                    )
                  else
                    const _UnavailableSection(
                      title: 'Staff performance',
                      message:
                          'Staff analytics will appear after call attribution passes real-device verification.',
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

/// Authorization boundary for owner-only Insights providers and presentation.
///
/// The builder is never invoked for an officer, so hidden sections cannot
/// subscribe to or compute owner-only data after direct route restoration.
class InsightsOwnerSectionBoundary extends ConsumerWidget {
  const InsightsOwnerSectionBoundary({
    super.key,
    required this.canViewOwnerSections,
    required this.builder,
  });

  final bool canViewOwnerSections;
  final Widget Function(BuildContext context, WidgetRef ref) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canViewOwnerSections) return const SizedBox.shrink();
    return builder(context, ref);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.preset,
    required this.grouping,
    required this.onPresetSelected,
    required this.onGroupingSelected,
  });

  final _DatePreset preset;
  final InsightsGrouping grouping;
  final ValueChanged<_DatePreset> onPresetSelected;
  final ValueChanged<InsightsGrouping> onGroupingSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date range', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _FilterChip(
                  label: 'This week',
                  selected: preset == _DatePreset.week,
                  onSelected: () => onPresetSelected(_DatePreset.week),
                ),
                _FilterChip(
                  label: 'This month',
                  selected: preset == _DatePreset.month,
                  onSelected: () => onPresetSelected(_DatePreset.month),
                ),
                _FilterChip(
                  label: 'Custom',
                  selected: preset == _DatePreset.custom,
                  onSelected: () => onPresetSelected(_DatePreset.custom),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Group by', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final option in InsightsGrouping.values)
                  _FilterChip(
                    label: switch (option) {
                      InsightsGrouping.daily => 'Daily',
                      InsightsGrouping.weekly => 'Weekly',
                      InsightsGrouping.monthly => 'Monthly',
                    },
                    selected: grouping == option,
                    onSelected: () => onGroupingSelected(option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _LegacyNotice extends StatelessWidget {
  const _LegacyNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colors.onTertiaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Excludes $count unassigned legacy ${count == 1 ? 'record' : 'records'} to protect business data boundaries.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: subtitle,
      child: value.when(
        data: builder,
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => const _SectionMessage(
          icon: Icons.error_outline,
          message: 'This section could not be loaded. Try again shortly.',
        ),
      ),
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: 'Not yet available',
      child: _SectionMessage(
        icon: Icons.lock_clock_outlined,
        message: message,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem(
    this.label,
    this.metric, {
    this.detail,
    this.valuePrefix = '',
    this.valueSuffix = '',
    this.showDelta = true,
  });

  final String label;
  final InsightMetric metric;
  final String? detail;
  final String valuePrefix;
  final String valueSuffix;
  final bool showDelta;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 3 : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _StatCard(item: item)),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = item.metric.value;
    final formatted = value is double
        ? value.toStringAsFixed(item.valuePrefix.isNotEmpty ? 2 : 0)
        : value.toString();
    final delta = item.metric.percentChange;
    final deltaLabel = delta == null
        ? 'New vs prior period'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs prior period';
    return Semantics(
      label:
          '${item.label}: ${item.valuePrefix}$formatted${item.valueSuffix}${item.detail == null ? '' : ', ${item.detail}'}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${item.valuePrefix}$formatted${item.valueSuffix}',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            if (item.detail != null)
              Text(
                item.detail!,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (item.showDelta)
              Text(
                deltaLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.items, required this.valueLabel});

  final List<RankedInsight> items;
  final String Function(num value) valueLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SectionMessage(
        icon: Icons.inbox_outlined,
        message: 'No activity in this period.',
      );
    }
    final maxValue = items.fold<num>(0, (max, item) {
      return item.value > max ? item.value : max;
    });
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _RankedRow(
            rank: index + 1,
            item: items[index],
            maximum: maxValue,
            valueLabel: valueLabel(items[index].value),
          ),
          if (index < items.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.rank,
    required this.item,
    required this.maximum,
    required this.valueLabel,
  });

  final int rank;
  final RankedInsight item;
  final num maximum;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fraction = maximum == 0 ? 0.0 : item.value / maximum;
    return Semantics(
      label:
          '$rank. ${item.label}, $valueLabel${item.secondaryValue == null ? '' : ', ${item.secondaryValue}'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: AppSpacing.xxl,
                  child: Text('$rank', style: AppTypography.labelLarge),
                ),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(valueLabel, style: AppTypography.labelMedium),
              ],
            ),
            if (item.secondaryValue != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxl),
                child: Text(
                  item.secondaryValue!,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: fraction.toDouble(),
                  minHeight: AppSpacing.sm,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

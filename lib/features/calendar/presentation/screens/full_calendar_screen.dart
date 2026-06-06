import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/combined_calendar_provider.dart';
import '../../../../widgets/hourly_grid/hourly_grid.dart';
import '../../../../extensions/datetime_semantics.dart';

class FullCalendarScreen extends ConsumerStatefulWidget {
  const FullCalendarScreen({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<FullCalendarScreen> createState() => _FullCalendarScreenState();
}

class _FullCalendarScreenState extends ConsumerState<FullCalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(combinedCalendarProvider(_selectedDate));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, MMM d').format(_selectedDate),
          style: AppTypography.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Pick Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                SemanticsService.announce(
                  'Now viewing ${_selectedDate.toFormattedDate()}',
                  ui.TextDirection.ltr,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Today',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
          ),
        ],
      ),
      body: blocksAsync.when(
        data: (blocks) => Semantics(
          label: 'Daily Schedule Grid for ${_selectedDate.toFormattedDate()}. '
              '${blocks.length} event${blocks.length == 1 ? '' : 's'} scheduled.',
          child: Column(
            children: [
              // Date navigation
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Text(
                        DateFormat('MMMM d, y').format(_selectedDate),
                        style: AppTypography.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Hourly grid
              Expanded(
                child: HourlyGrid(
                  blocks: blocks,
                  date: _selectedDate,
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Error: $e', style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
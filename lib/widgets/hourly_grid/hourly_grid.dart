import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/calendar_block.dart';
import '../../core/theme/app_colors.dart';
import 'hourly_grid_constants.dart';
import 'hourly_grid_layout.dart';
import 'event_card.dart';

class HourlyGrid extends ConsumerStatefulWidget {
  const HourlyGrid({
    super.key,
    required this.blocks,
    required this.date,
  });

  final List<CalendarBlock> blocks;
  final DateTime date;

  @override
  ConsumerState<HourlyGrid> createState() => _HourlyGridState();
}

class _HourlyGridState extends ConsumerState<HourlyGrid> {
  late ScrollController _scrollController;
  late Timer _nowTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _scrollToNow() {
    final offset = (nowOffset() - 200).clamp(0.0, kGridTotalHeight);
    _scrollController.jumpTo(offset);
  }

  @override
  void dispose() {
    _nowTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lanes = assignLanes(widget.blocks);
    final maxLane = lanes.isEmpty
        ? 0
        : lanes.values.reduce((a, b) => a > b ? a : b) + 1;

    return Row(
      children: [
        // Time label column
        SizedBox(
          width: kTimeLabelWidth,
          child: Column(
            children: List.generate(24, (hour) {
              return SizedBox(
                height: kHourHeight,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      DateFormat('ha').format(DateTime(2024, 1, 1, hour)),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Grid column
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: kGridTotalHeight,
              child: Stack(
                children: [
                  // Hour dividers
                  ...List.generate(24, (hour) {
                    return Positioned(
                      top: hour * kHourHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: AppColors.outline.withValues(alpha: 0.2),
                      ),
                    );
                  }),
                  // Now indicator
                  Positioned(
                    top: nowOffset(),
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Event cards
                  ...widget.blocks.map((block) {
                    final lane = lanes[block] ?? 0;
                    final availableWidth =
                        MediaQuery.of(context).size.width - kTimeLabelWidth - 32;
                    final laneWidth = maxLane > 0
                        ? (availableWidth / maxLane) - 4.0
                        : availableWidth;
                    final left = lane * (availableWidth / maxLane.clamp(1, maxLane)) + 2.0;

                    return Positioned(
                      top: topOffsetFor(block.start),
                      left: left,
                      width: laneWidth,
                      height: cardHeightFor(block),
                      child: RepaintBoundary(
                        child: EventCard(block: block),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
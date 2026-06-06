import 'hourly_grid_constants.dart';
import '../../core/models/calendar_block.dart';

/// Pixel offset from the top of the grid for a given [dateTime].
double topOffsetFor(DateTime dateTime) =>
    (dateTime.hour + dateTime.minute / 60.0) * kHourHeight;

/// Pixel height for an event card given its duration.
double cardHeightFor(CalendarBlock block) {
  final hours = block.duration.inMinutes / 60.0;
  return (hours * kHourHeight).clamp(kMinCardHeight, kGridTotalHeight);
}

/// Current-time indicator offset.
double nowOffset() {
  final now = DateTime.now();
  return topOffsetFor(now);
}

/// Groups overlapping blocks into lanes for side-by-side rendering.
/// Returns a map of CalendarBlock → lane index (0-based).
Map<CalendarBlock, int> assignLanes(List<CalendarBlock> blocks) {
  final lanes = <CalendarBlock, int>{};
  for (final block in blocks) {
    final overlapping = blocks
        .where((b) =>
            b != block &&
            b.overlapsWith(block) &&
            lanes.containsKey(b))
        .map((b) => lanes[b]!)
        .toSet();
    var lane = 0;
    while (overlapping.contains(lane)) {
      lane++;
    }
    lanes[block] = lane;
  }
  return lanes;
}
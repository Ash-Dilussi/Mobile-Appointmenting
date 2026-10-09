enum InsightsGrouping { daily, weekly, monthly }

class InsightsQuery {
  const InsightsQuery({
    required this.institutionId,
    required this.start,
    required this.end,
    required this.grouping,
  });

  final String institutionId;
  final DateTime start;
  final DateTime end;
  final InsightsGrouping grouping;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is InsightsQuery &&
      other.institutionId == institutionId &&
      other.start == start &&
      other.end == end &&
      other.grouping == grouping;

  @override
  int get hashCode => Object.hash(institutionId, start, end, grouping);
}

class InsightMetric {
  const InsightMetric({required this.value, required this.previousValue});

  final num value;
  final num previousValue;

  double? get percentChange {
    if (previousValue == 0) return value == 0 ? 0 : null;
    return ((value - previousValue) / previousValue) * 100;
  }
}

class AppointmentInsights {
  const AppointmentInsights({
    required this.booked,
    required this.completed,
    required this.cancelled,
    required this.noShow,
  });

  final InsightMetric booked;
  final InsightMetric completed;
  final InsightMetric cancelled;
  final InsightMetric noShow;

  double rate(int count) => booked.value == 0 ? 0 : count / booked.value * 100;
}

class CustomerInsights {
  const CustomerInsights({
    required this.newCustomers,
    required this.returningCustomers,
  });

  final InsightMetric newCustomers;
  final InsightMetric returningCustomers;

  double get repeatVisitRate {
    final total = newCustomers.value + returningCustomers.value;
    return total == 0 ? 0 : returningCustomers.value / total * 100;
  }
}

class RankedInsight {
  const RankedInsight({
    required this.id,
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final String id;
  final String label;
  final num value;
  final String? secondaryValue;
}

class CallInsights {
  const CallInsights({
    required this.total,
    required this.answered,
    required this.missed,
    required this.averageDurationSeconds,
    required this.converted,
  });

  final InsightMetric total;
  final InsightMetric answered;
  final InsightMetric missed;
  final InsightMetric averageDurationSeconds;
  final InsightMetric converted;

  double get conversionRate =>
      total.value == 0 ? 0 : converted.value / total.value * 100;
}

class BookedValueInsights {
  const BookedValueInsights({
    required this.total,
    required this.averagePerAppointment,
    required this.byService,
  });

  final InsightMetric total;
  final InsightMetric averagePerAppointment;
  final List<RankedInsight> byService;
}

class StaffInsights {
  const StaffInsights({required this.people});

  final List<RankedInsight> people;
}

class LegacyExclusionInsights {
  const LegacyExclusionInsights({required this.recordCount});

  final int recordCount;
}

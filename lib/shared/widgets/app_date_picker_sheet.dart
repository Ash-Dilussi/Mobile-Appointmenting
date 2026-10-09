import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../utils/tap_guard.dart';

const double _pickerHeight = 216;
final _pickerTapGuards = Expando<TapGuard>();

/// Shows the app's locale-aware wheel date picker.
///
/// Changes remain local to the sheet until the user selects Done. Dismissing
/// the sheet or selecting Cancel returns `null`.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime minimumDate,
  required DateTime maximumDate,
  required String title,
}) {
  final normalizedMinimum = _dateOnly(minimumDate);
  final normalizedMaximum = _dateOnly(maximumDate);
  if (normalizedMaximum.isBefore(normalizedMinimum)) {
    throw ArgumentError.value(
      maximumDate,
      'maximumDate',
      'must be on or after minimumDate',
    );
  }

  final normalizedInitial = _clampDate(
    _dateOnly(initialDate),
    normalizedMinimum,
    normalizedMaximum,
  );

  return _showAppPickerSheet<DateTime>(
    context: context,
    builder: (_) => _AppDatePickerSheet(
      initialDate: normalizedInitial,
      minimumDate: normalizedMinimum,
      maximumDate: normalizedMaximum,
      title: title,
    ),
  );
}

/// Shows the app's wheel time picker using the device's 12/24-hour setting.
///
/// Changes remain local to the sheet until the user selects Done. Dismissing
/// the sheet or selecting Cancel returns `null`.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Select time',
}) {
  return _showAppPickerSheet<TimeOfDay>(
    context: context,
    builder: (_) => _AppTimePickerSheet(
      initialTime: initialTime,
      title: title,
    ),
  );
}

Future<T?> _showAppPickerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final tapGuard = _pickerTapGuards[context] ??= TapGuard();
  if (!tapGuard.tryAcquire()) return null;

  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
    reverseDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
  );

  try {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: controller,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      builder: builder,
    );
    if (controller.status != AnimationStatus.dismissed) {
      await controller.reverse();
    }
    return result;
  } finally {
    controller.dispose();
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _clampDate(DateTime value, DateTime minimum, DateTime maximum) {
  if (value.isBefore(minimum)) return minimum;
  if (value.isAfter(maximum)) return maximum;
  return value;
}

class _AppDatePickerSheet extends StatefulWidget {
  const _AppDatePickerSheet({
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
    required this.title,
  });

  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final String title;

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _pendingDate;

  @override
  void initState() {
    super.initState();
    _pendingDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return _AppPickerSheetChrome(
      title: widget.title,
      onDone: () => Navigator.of(context).pop(_pendingDate),
      pickerThemeKey: const Key('app-date-picker-cupertino-theme'),
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: widget.initialDate,
        minimumDate: widget.minimumDate,
        maximumDate: widget.maximumDate,
        onDateTimeChanged: (value) {
          _pendingDate = _dateOnly(value);
        },
      ),
    );
  }
}

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({
    required this.initialTime,
    required this.title,
  });

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  late DateTime _pendingTime;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _pendingTime = DateTime(
      today.year,
      today.month,
      today.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppPickerSheetChrome(
      title: widget.title,
      onDone: () => Navigator.of(context).pop(
        TimeOfDay.fromDateTime(_pendingTime),
      ),
      pickerThemeKey: const Key('app-time-picker-cupertino-theme'),
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: _pendingTime,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        minuteInterval: 1,
        onDateTimeChanged: (value) {
          _pendingTime = value;
        },
      ),
    );
  }
}

class _AppPickerSheetChrome extends StatelessWidget {
  const _AppPickerSheetChrome({
    required this.title,
    required this.onDone,
    required this.picker,
    required this.pickerThemeKey,
  });

  final String title;
  final VoidCallback onDone;
  final Widget picker;
  final Key pickerThemeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cupertinoTheme = CupertinoTheme.of(context).copyWith(
      brightness: theme.brightness,
      primaryColor: colors.primary,
    );

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style:
                    AppTypography.titleLarge.copyWith(color: colors.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: _pickerHeight,
                width: double.infinity,
                child: CupertinoTheme(
                  key: pickerThemeKey,
                  data: cupertinoTheme,
                  child: picker,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

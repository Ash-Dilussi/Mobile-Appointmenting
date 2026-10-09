import 'dart:async';

import 'package:flutter/material.dart';

/// Shared close/back behavior for full-screen forms with unsaved changes.
mixin UnsavedChangesGuard<T extends StatefulWidget> on State<T> {
  bool _allowPopWithoutPrompt = false;
  bool _discardDialogVisible = false;

  bool get hasUnsavedChanges;

  bool get canPopWithoutDiscardConfirmation =>
      _allowPopWithoutPrompt || !hasUnsavedChanges;

  Future<void> handleCloseRequest(
    FutureOr<void> Function() leaveScreen,
  ) async {
    if (_discardDialogVisible) return;

    var shouldLeave = !hasUnsavedChanges;
    if (!shouldLeave) {
      _discardDialogVisible = true;
      try {
        shouldLeave = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                final colors = Theme.of(dialogContext).colorScheme;
                return AlertDialog(
                  title: const Text('Discard changes?'),
                  content: const Text(
                    'You have unsaved changes. If you leave now, they will be lost.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Discard'),
                    ),
                  ],
                );
              },
            ) ??
            false;
      } finally {
        _discardDialogVisible = false;
      }
    }

    if (!shouldLeave || !mounted) return;
    await allowPopWithoutPrompt();
    if (mounted) await Future<void>.sync(leaveScreen);
  }

  /// Marks a successful save/delete as handled before its navigation occurs.
  Future<void> allowPopWithoutPrompt() async {
    if (_allowPopWithoutPrompt || !mounted) return;
    setState(() => _allowPopWithoutPrompt = true);
    await WidgetsBinding.instance.endOfFrame;
  }
}

bool orderedListsEqual<T>(
  List<T> first,
  List<T> second,
  bool Function(T first, T second) equals,
) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!equals(first[index], second[index])) return false;
  }
  return true;
}

bool mapsEqualByValue<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/logging/logger_service.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  final int? serviceId;

  const AddServiceScreen({super.key, this.serviceId});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen>
    with UnsavedChangesGuard<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _costController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  Service? _existingService;
  int _selectedColorValue = ServiceColorPalette.defaultValue;
  late _ServiceFormSnapshot _baseline;
  bool _baselineReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.serviceId != null) {
      _isEditing = true;
      _loadService();
    } else {
      _captureBaseline();
    }
    for (final controller in [
      _titleController,
      _durationController,
      _costController,
      _descriptionController,
    ]) {
      controller.addListener(_refreshDirtyState);
    }
  }

  void _refreshDirtyState() {
    if (mounted) setState(() {});
  }

  void _captureBaseline() {
    _baseline = _currentSnapshot();
    _baselineReady = true;
  }

  _ServiceFormSnapshot _currentSnapshot() => _ServiceFormSnapshot(
        title: _titleController.text.trim(),
        duration: _durationController.text.trim(),
        cost: _costController.text.trim(),
        description: _descriptionController.text.trim(),
        colorValue: _selectedColorValue,
      );

  @override
  bool get hasUnsavedChanges =>
      _baselineReady && !_baseline.matches(_currentSnapshot());

  Future<void> _leaveScreen() async {
    context.goNamed('service-management');
  }

  Future<void> _loadService() async {
    final db = ref.read(homeHiveProvider);
    try {
      final service = db.getServiceById(widget.serviceId!);
      if (service != null && mounted) {
        setState(() {
          _existingService = service;
          _titleController.text = service.title;
          _durationController.text = service.defaultDurationMinutes.toString();
          _costController.text = service.cost.toString();
          _descriptionController.text = service.description ?? '';
          _selectedColorValue = ServiceColorPalette.resolve(
            service.colorValue,
          ).argbValue;
          _captureBaseline();
        });
      } else {
        _captureBaseline();
      }
    } catch (e, st) {
      logger.error('AddServiceScreen', 'Failed to load service: $e',
          error: e, stackTrace: st);
      if (!_baselineReady) _captureBaseline();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(homeHiveProvider);

      final title = _titleController.text.trim();
      final duration = int.tryParse(_durationController.text) ?? 30;
      final cost = double.tryParse(_costController.text) ?? 0.0;
      final description = _descriptionController.text.trim();

      if (_isEditing && _existingService != null) {
        // Update existing service
        final updated = Service()
          ..title = title
          ..defaultDurationMinutes = duration
          ..cost = cost
          ..description = description.isNotEmpty ? description : null
          ..colorValue = _selectedColorValue
          ..createdAt = _existingService!.createdAt
          ..updatedAt = DateTime.now()
          ..synced = false
          ..isActive = _existingService!.isActive
          ..institutionId = _existingService!.institutionId;
        await db.updateService(_existingService!.id!, updated);
      } else {
        // Create new service
        final institutionId = ref.read(authSessionProvider)?.institutionId;
        if (institutionId == null || institutionId.isEmpty) {
          throw StateError('An institution is required to create a service.');
        }
        final newService = Service()
          ..institutionId = institutionId
          ..title = title
          ..defaultDurationMinutes = duration
          ..cost = cost
          ..description = description.isNotEmpty ? description : null
          ..colorValue = _selectedColorValue
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;

        await db.insertService(newService);
      }

      await allowPopWithoutPrompt();
      if (mounted) {
        context.goNamed('service-management');
      }
    } catch (e, st) {
      logger.error('AddServiceScreen', 'Failed to save service: $e',
          error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving service: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope<Object?>(
      canPop: canPopWithoutDiscardConfirmation,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await handleCloseRequest(_leaveScreen);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => handleCloseRequest(_leaveScreen),
          ),
          title: Text(_isEditing ? 'Edit Service' : 'Add New Service'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Service Title',
                    hintText: 'e.g., Haircut, Consultation',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a service title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Duration and Cost Row
                Row(
                  children: [
                    // Duration
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          hintText: '30',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final duration = int.tryParse(value);
                          if (duration == null || duration <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Cost
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cost (\$)',
                          hintText: '0.00',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final cost = double.tryParse(value);
                          if (cost == null || cost < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Appointment badge color',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose one of 10 colors. This identifies the service in appointment views.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ServiceColorPicker(
                  selectedValue: _selectedColorValue,
                  onSelected: (value) {
                    setState(() => _selectedColorValue = value);
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add any notes about this service...',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Save Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(_isEditing ? 'Update Service' : 'Save Service'),
                ),

                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => _showDeleteDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                    child: const Text('Delete Service'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${_existingService?.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    if (_existingService == null) {
      return;
    }

    try {
      final db = ref.read(homeHiveProvider);
      await db.deleteService(_existingService!.id!);
      await allowPopWithoutPrompt();
      if (mounted) {
        context.goNamed('service-management');
      }
    } catch (e, st) {
      logger.error('AddServiceScreen', 'Failed to delete service: $e',
          error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting service: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _ServiceFormSnapshot {
  final String title;
  final String duration;
  final String cost;
  final String description;
  final int colorValue;

  const _ServiceFormSnapshot({
    required this.title,
    required this.duration,
    required this.cost,
    required this.description,
    required this.colorValue,
  });

  bool matches(_ServiceFormSnapshot other) =>
      title == other.title &&
      duration == other.duration &&
      cost == other.cost &&
      description == other.description &&
      colorValue == other.colorValue;
}

class _ServiceColorPicker extends StatelessWidget {
  const _ServiceColorPicker({
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: ServiceColorPalette.options.map((option) {
            final isSelected = option.argbValue == selectedValue;

            return Semantics(
              button: true,
              selected: isSelected,
              label: '${option.name} service color',
              child: Tooltip(
                message: option.name,
                child: InkResponse(
                  onTap: () => onSelected(option.argbValue),
                  radius: 28,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colors.onSurface
                            : colors.outlineVariant,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: option.onColor,
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Selected: ${ServiceColorPalette.resolve(selectedValue).name}',
          style: AppTypography.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

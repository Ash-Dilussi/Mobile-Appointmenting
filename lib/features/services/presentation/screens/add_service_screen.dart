import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/logging/logger_service.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  final int? serviceId;

  const AddServiceScreen({super.key, this.serviceId});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _costController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  Service? _existingService;

  @override
  void initState() {
    super.initState();
    if (widget.serviceId != null) {
      _isEditing = true;
      _loadService();
    }
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
        });
      }
    } catch (e, st) {
      logger.error('AddServiceScreen', 'Failed to load service: $e',
          error: e, stackTrace: st);
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
          ..createdAt = _existingService!.createdAt
          ..updatedAt = DateTime.now()
          ..synced = false;
        await db.updateService(_existingService!.id!, updated);
      } else {
        // Create new service
        final newService = Service()
          ..title = title
          ..defaultDurationMinutes = duration
          ..cost = cost
          ..description = description.isNotEmpty ? description : null
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;

        await db.insertService(newService);
      }

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
            backgroundColor: AppColors.error,
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.goNamed('service-management'),
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimaryContainer,
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
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Delete Service'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
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
              backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

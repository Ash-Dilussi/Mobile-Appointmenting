import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/logging/logger_service.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AddStationScreen extends ConsumerStatefulWidget {
  final int? stationId;

  const AddStationScreen({super.key, this.stationId});

  @override
  ConsumerState<AddStationScreen> createState() => _AddStationScreenState();
}

class _AddStationScreenState extends ConsumerState<AddStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  ServiceStation? _existingStation;

  @override
  void initState() {
    super.initState();
    logger.info('AddStationScreen',
        'Screen initialized, editing: ${widget.stationId != null}');
    if (widget.stationId != null) {
      _isEditing = true;
      _loadStation();
    }
  }

  Future<void> _loadStation() async {
    logger.info('AddStationScreen',
        'Loading station for editing, id: ${widget.stationId}');
    final db = ref.read(homeHiveProvider);
    try {
      final station = db.getServiceStationById(widget.stationId!);
      if (station != null && mounted) {
        setState(() {
          _existingStation = station;
          _nameController.text = station.name;
          _addressController.text = station.address ?? '';
          _phoneController.text = station.phone ?? '';
          _descriptionController.text = station.description ?? '';
        });
        logger.info(
            'AddStationScreen', 'Station loaded successfully: ${station.name}');
      } else {
        logger.warning('AddStationScreen',
            'Station not found for id: ${widget.stationId}');
      }
    } catch (e, st) {
      logger.error('AddStationScreen', 'Failed to load station: $e',
          error: e, stackTrace: st);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    logger.info('AddStationScreen', '_handleSave started');
    if (!(_formKey.currentState?.validate() ?? false)) {
      logger.warning('AddStationScreen', 'Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(homeHiveProvider);
      logger.info('AddStationScreen', 'Got database: $db');

      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final phone = _phoneController.text.trim();
      final description = _descriptionController.text.trim();

      logger.info('AddStationScreen', 'Form values - name: $name');

      if (_isEditing && _existingStation != null) {
        logger.info('AddStationScreen',
            'Updating station id: ${_existingStation!.id}, name: $name');
        final updated = ServiceStation()
          ..name = name
          ..address = address.isNotEmpty ? address : null
          ..phone = phone.isNotEmpty ? phone : null
          ..description = description.isNotEmpty ? description : null
          ..createdAt = _existingStation!.createdAt
          ..updatedAt = DateTime.now()
          ..synced = false;
        await db.updateServiceStation(_existingStation!.id!, updated);
        logger.info('AddStationScreen', 'Station updated successfully: $name');
      } else {
        logger.info('AddStationScreen', 'Creating new station: $name');

        final newStation = ServiceStation()
          ..name = name
          ..address = address.isNotEmpty ? address : null
          ..phone = phone.isNotEmpty ? phone : null
          ..description = description.isNotEmpty ? description : null
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;
        logger.info('AddStationScreen', 'Station object created: $newStation');

        await db.insertServiceStation(newStation);
        logger.info('AddStationScreen', 'Station created successfully: $name');
      }

      if (mounted) {
        context.goNamed('station-management');
      }
    } catch (e, st) {
      logger.error('AddStationScreen', 'Failed to save station: $e',
          error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving station: $e'),
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

  Future<void> _handleDelete() async {
    if (_existingStation == null) {
      logger.warning('AddStationScreen', 'Cannot delete: no station loaded');
      return;
    }

    logger.info('AddStationScreen',
        'Deleting station id: ${_existingStation!.id}, name: ${_existingStation!.name}');
    try {
      final db = ref.read(homeHiveProvider);
      await db.deleteServiceStation(_existingStation!.id!);
      logger.info('AddStationScreen',
          'Station deleted successfully: ${_existingStation!.name}');
      if (mounted) {
        context.goNamed('station-management');
      }
    } catch (e, st) {
      logger.error('AddStationScreen', 'Failed to delete station: $e',
          error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting station: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
          onPressed: () => context.goNamed('station-management'),
        ),
        title: Text(_isEditing ? 'Edit Station' : 'Add New Station'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  hintText: 'e.g., Main Branch, Downtown',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a station name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Address
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Enter station address',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: 'Enter station phone',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add any notes about this station...',
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
                    : Text(_isEditing ? 'Update Station' : 'Save Station'),
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
                  child: const Text('Delete Station'),
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
        title: const Text('Delete Station'),
        content: Text(
          'Are you sure you want to delete "${_existingStation?.name}"? This action cannot be undone.',
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
}

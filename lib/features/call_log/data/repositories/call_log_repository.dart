import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/collections/customer.dart';
import '../models/call_log_entry.dart';

class CallLogRepository {
  static const _uuid = Uuid();
  late Box<CallLogEntry> _box;
  late Box<Customer> _customerBox;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _box = await Hive.openBox<CallLogEntry>(CallLogBox.boxName);
    _customerBox = Hive.box<Customer>('customers');
    _initialized = true;
  }

  /// Normalize phone number for comparison
  /// Strips spaces, dashes, parentheses, and leading country codes (+94 / 0094 / 0)
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Handle Sri Lankan numbers
    // +94 -> 94, 0094 -> 94, 0 -> (remove leading 0)
    if (normalized.startsWith('94') && normalized.length > 10) {
      // Already has country code, remove leading 94 if followed by mobile prefix
      if (normalized.startsWith('94')) {
        normalized = normalized.substring(2);
      }
    } else if (normalized.startsWith('0094')) {
      normalized = normalized.substring(4);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  /// Find customer by normalized phone number
  Customer? _findCustomerByPhone(String phoneNumber) {
    final normalizedInput = _normalizePhoneNumber(phoneNumber);

    for (final customer in _customerBox.values) {
      final normalizedCustomer = _normalizePhoneNumber(customer.phoneNumber);
      if (normalizedCustomer == normalizedInput) {
        return customer;
      }
    }
    return null;
  }

  /// Save a new entry (called when RINGING is detected)
  Future<void> saveEntry(CallLogEntry entry) async {
    await _ensureInitialized();

    // Try to match customer by phone number
    final customer = _findCustomerByPhone(entry.phoneNumber);
    if (customer != null) {
      entry.customerId = customer.id;
      entry.customerName = customer.name;
    }

    // Generate UUID if not set
    if (entry.id.isEmpty) {
      entry.id = _uuid.v4();
    }

    await _box.add(entry);
  }

  /// Update an existing entry by id (called on OFFHOOK and IDLE)
  Future<void> updateEntry(
    String id, {
    String? state,
    DateTime? endTime,
    int? durationSeconds,
  }) async {
    await _ensureInitialized();

    final entry = getEntryById(id);
    if (entry == null) return;

    if (state != null) {
      entry.state = state;
    }

    if (endTime != null) {
      entry.endTime = endTime;
      // Compute duration if we have start time
      if (entry.startTime != null) {
        entry.durationSeconds = endTime.difference(entry.startTime).inSeconds;
      }
    }

    if (durationSeconds != null) {
      entry.durationSeconds = durationSeconds;
    }

    await entry.save();
  }

  /// Get all entries ordered by startTime descending (most recent first)
  List<CallLogEntry> getAllEntries() {
    final entries = _box.values.toList();
    entries.sort((a, b) => b.startTime.compareTo(a.startTime));
    return entries;
  }

  /// Watch all entries - returns a stream that emits on changes
  Stream<List<CallLogEntry>> watchAllEntries() {
    final controller = StreamController<List<CallLogEntry>>();
    controller.add(getAllEntries()); // Add BEFORE returning

    final subscription = _box.watch().listen((_) {
      controller.add(getAllEntries());
    });

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Single entry lookup by id
  CallLogEntry? getEntryById(String id) {
    try {
      return _box.values.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete single entry
  Future<void> deleteEntry(String id) async {
    await _ensureInitialized();

    final entry = getEntryById(id);
    if (entry != null) {
      await entry.delete();
    }
  }

  /// Get entry by Hive key
  CallLogEntry? getEntryByKey(dynamic key) {
    try {
      return _box.get(key);
    } catch (e) {
      return null;
    }
  }
}

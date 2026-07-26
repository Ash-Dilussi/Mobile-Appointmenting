// lib/features/subscription/data/subscription_repository_impl.dart
//
// Firestore path:  institutions/{institutionId}/subscription  (single doc)
// Hive key:        "sub_{institutionId}"  in  Box<String> subscriptionBox

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../../../core/entitlements/plan_tier.dart';
import '../../../core/logging/logger_service.dart';
import '../domain/subscription_plan.dart';
import 'subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    required FirebaseFirestore firestore,
    required Box<String> subscriptionBox,
  })  : _firestore = firestore,
        _box = subscriptionBox;

  final FirebaseFirestore _firestore;
  final Box<String> _box;

  // ── Hive cache ───────────────────────────────────────────────────────────

  @override
  Future<SubscriptionPlan?> getCachedPlan({
    required String institutionId,
  }) async {
    final raw = _box.get(_cacheKey(institutionId));
    if (raw == null) return null;
    try {
      return SubscriptionPlan.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      LoggerService.instance.log(
        LogLevel.warning,
        'SubscriptionRepo',
        'Cache parse failed — ignoring: $e',
      );
      return null;
    }
  }

  // ── Firestore fetch ───────────────────────────────────────────────────────

  @override
  Future<SubscriptionPlan> fetchPlan({required String institutionId}) async {
    final snap = await _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('subscription')
        .doc('plan')
        .get();

    final plan = snap.exists && snap.data() != null
        ? SubscriptionPlan.fromFirestore(
            institutionId: institutionId,
            data: snap.data()!,
          )
        : SubscriptionPlan.freeTier(institutionId);

    // Update Hive cache after every successful fetch
    await _writeCache(plan);
    LoggerService.instance.log(
      LogLevel.info,
      'SubscriptionRepo',
      'Plan fetched for $institutionId: ${plan.tier.displayName}',
    );

    return plan;
  }

  // ── Activate (post-payment) ───────────────────────────────────────────────

  @override
  Future<void> activatePlan({
    required String institutionId,
    required PlanTier tier,
    required DateTime expiresAt,
    String? stripeSubscriptionId,
    String? paddleSubscriptionId,
  }) async {
    final data = <String, dynamic>{
      'tier': tier.toJson(),
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
      if (stripeSubscriptionId != null)
        'stripeSubscriptionId': stripeSubscriptionId,
      if (paddleSubscriptionId != null)
        'paddleSubscriptionId': paddleSubscriptionId,
    };

    await _firestore
        .collection('institutions')
        .doc(institutionId)
        .collection('subscription')
        .doc('plan')
        .set(data, SetOptions(merge: true));

    final updated = SubscriptionPlan(
      institutionId: institutionId,
      tier: tier,
      expiresAt: expiresAt,
      stripeSubscriptionId: stripeSubscriptionId,
      paddleSubscriptionId: paddleSubscriptionId,
    );
    await _writeCache(updated);

    LoggerService.instance.log(
      LogLevel.info,
      'SubscriptionRepo',
      'Plan activated for $institutionId: ${tier.displayName} until $expiresAt',
    );
  }

  String _cacheKey(String institutionId) => 'sub_$institutionId';

  Future<void> _writeCache(SubscriptionPlan plan) async {
    await _box.put(_cacheKey(plan.institutionId), jsonEncode(plan.toJson()));
  }
}

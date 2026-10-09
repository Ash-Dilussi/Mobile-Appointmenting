import 'dart:async';
import 'dart:io';

import 'package:bookly/core/entitlements/entitlement_provider.dart';
import 'package:bookly/core/entitlements/plan_tier.dart';
import 'package:bookly/features/subscription/data/subscription_repository.dart';
import 'package:bookly/features/subscription/domain/subscription_plan.dart';
import 'package:bookly/core/logging/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDirectory = await Directory.systemTemp.createTemp(
      'entitlement_provider_test_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDirectory.path);
    await logger.init();
  });

  tearDownAll(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('startup bootstrap returns cached access without waiting for network',
      () async {
    final repository = _DelayedSubscriptionRepository(
      cached: const SubscriptionPlan(
        institutionId: 'institution-1',
        tier: PlanTier.pro,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(entitlementProvider);
    await container
        .read(entitlementProvider.notifier)
        .bootstrap(institutionId: 'institution-1');

    expect(container.read(entitlementProvider).effectiveTier, PlanTier.pro);
    expect(repository.remoteFetchStarted, isTrue);
    expect(repository.remoteFetch.isCompleted, isFalse);
  });

  test('startup bootstrap defaults to free while network refresh is pending',
      () async {
    final repository = _DelayedSubscriptionRepository(cached: null);
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(entitlementProvider);
    await container
        .read(entitlementProvider.notifier)
        .bootstrap(institutionId: 'institution-1');

    expect(container.read(entitlementProvider).isLoading, isFalse);
    expect(container.read(entitlementProvider).effectiveTier, PlanTier.free);
  });
}

class _DelayedSubscriptionRepository implements SubscriptionRepository {
  _DelayedSubscriptionRepository({required this.cached});

  final SubscriptionPlan? cached;
  final Completer<SubscriptionPlan> remoteFetch = Completer<SubscriptionPlan>();
  bool remoteFetchStarted = false;

  @override
  Future<SubscriptionPlan?> getCachedPlan(
      {required String institutionId}) async {
    return cached;
  }

  @override
  Future<SubscriptionPlan> fetchPlan({required String institutionId}) {
    remoteFetchStarted = true;
    return remoteFetch.future;
  }

  @override
  Future<void> activatePlan({
    required String institutionId,
    required PlanTier tier,
    required DateTime expiresAt,
    String? stripeSubscriptionId,
    String? paddleSubscriptionId,
  }) async {}
}

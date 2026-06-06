import 'package:hive_flutter/hive_flutter.dart';
import '../../features/auth/data/models/cached_user_profile.dart';
import '../../features/auth/domain/entities/auth_user.dart';

class HiveInitializer {
  HiveInitializer._();

  static const String authCacheBox = 'auth_cache';
  static const String _currentUserKey = 'current_user';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CachedUserProfileAdapter());
    await Hive.openBox<CachedUserProfile>(authCacheBox);
  }

  static Box<CachedUserProfile> get authBox =>
      Hive.box<CachedUserProfile>(authCacheBox);

  static CachedUserProfile? readCachedUser() => authBox.get(_currentUserKey);

  static Future<void> writeCachedUser(AuthUser user) =>
      authBox.put(_currentUserKey, CachedUserProfile.fromAuthUser(user));

  static Future<void> clearCachedUser() => authBox.delete(_currentUserKey);
}
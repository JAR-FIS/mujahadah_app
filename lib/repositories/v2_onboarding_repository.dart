import 'package:hive/hive.dart';

/// Abstract contract for managing V2 onboarding completion state.
abstract class V2OnboardingRepository {
  /// Returns whether the 5-screen onboarding has been affirmatively completed.
  Future<bool> isCompleted();

  /// Persists the onboarding completion status.
  Future<void> setCompleted(bool completed);

  /// Clears the onboarding completion flag (for testing or app reset).
  Future<void> clear();
}

/// Hive-backed persistent repository for V2 onboarding.
///
/// Stores completion status under the namespaced key `v2_onboarding_completed` in the
/// `settings` box, strictly decoupled from initial preferences and profile setup.
class HiveV2OnboardingRepository implements V2OnboardingRepository {
  static const String defaultBoxName = 'settings';
  static const String keyCompleted = 'v2_onboarding_completed';

  final Box? _explicitBox;
  final Future<void> Function(String key, dynamic value)? onBeforePut;

  HiveV2OnboardingRepository({
    Box? box,
    this.onBeforePut,
  }) : _explicitBox = box;

  Box get _box {
    if (_explicitBox != null) return _explicitBox!;
    if (Hive.isBoxOpen(defaultBoxName)) {
      return Hive.box(defaultBoxName);
    }
    throw StateError(
      'Hive box "$defaultBoxName" is not opened. Ensure Hive is initialized '
      'or provide an explicit Box instance.',
    );
  }

  @override
  Future<bool> isCompleted() async {
    final raw = _box.get(keyCompleted, defaultValue: false);
    return raw is bool ? raw : false;
  }

  @override
  Future<void> setCompleted(bool completed) async {
    if (onBeforePut != null) {
      await onBeforePut!(keyCompleted, completed);
    }
    await _box.put(keyCompleted, completed);
  }

  @override
  Future<void> clear() async {
    await _box.delete(keyCompleted);
  }
}

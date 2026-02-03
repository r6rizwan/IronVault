import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';

final autoLockProvider = NotifierProvider<AutoLockController, bool>(
  AutoLockController.new,
);

class AutoLockController extends Notifier<bool> {
  DateTime? _pausedAt;
  static const int _minBackgroundSeconds = 2;

  @override
  bool build() {
    return false; // unlocked by default
  }

  /// Called when app goes inactive OR paused
  void markPaused() {
    _pausedAt = DateTime.now();
  }

  /// Decide if app should lock when resumed
  Future<void> evaluateLockOnResume() async {
    final storage = ref.read(secureStorageProvider);
    final timer = await storage.readValue("auto_lock_timer") ?? "immediately";

    if (_pausedAt == null) return;
    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    if (elapsed < _minBackgroundSeconds) {
      _resetPauseState();
      return;
    }

    if (timer == "immediately") {
      state = true;
      _resetPauseState();
      return;
    }

    final seconds = int.tryParse(timer);
    if (seconds == null || _pausedAt == null) {
      _resetPauseState();
      return;
    }

    if (elapsed >= seconds) {
      state = true;
    }

    _resetPauseState();
  }

  /// Manual unlock
  void unlock() {
    state = false;
  }

  void _resetPauseState() {
    _pausedAt = null;
  }
}

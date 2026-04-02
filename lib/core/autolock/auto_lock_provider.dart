import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';

final autoLockProvider = NotifierProvider<AutoLockController, bool>(
  AutoLockController.new,
);

class AutoLockController extends Notifier<bool> {
  DateTime? _pausedAt;
  bool _suspended = false;
  bool _forceImmediateOnResume = false;
  // Ignore ultra-brief inactive/resume transitions (notification shade flicker).
  // Keep this low so phone lock/app switch still triggers lock reliably.
  static const int _minBackgroundSeconds = 1;

  @override
  bool build() {
    return false; // unlocked by default
  }

  /// Called when app goes inactive OR paused
  void markPaused({bool forceImmediate = false}) {
    if (_suspended) return;
    _pausedAt ??= DateTime.now();
    if (forceImmediate) _forceImmediateOnResume = true;
  }

  /// Decide if app should lock when resumed
  Future<bool> evaluateLockOnResume() async {
    final forceImmediate = _forceImmediateOnResume;
    _forceImmediateOnResume = false;

    if (_suspended) {
      _resetPauseState();
      return false;
    }
    final storage = ref.read(secureStorageProvider);
    final pinHash = await storage.readPinHash();
    if (pinHash == null || pinHash.isEmpty) {
      _resetPauseState();
      return false;
    }
    final lockOnSwitchValue = await storage.readValue('auto_lock_on_switch');
    final lockOnSwitchEnabled = (lockOnSwitchValue ?? 'true') == 'true';
    if (!lockOnSwitchEnabled) {
      _resetPauseState();
      return false;
    }
    final timer = await storage.readValue("auto_lock_timer") ?? "immediately";

    if (_pausedAt == null) return false;
    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    if (forceImmediate) {
      state = true;
      _resetPauseState();
      return true;
    }

    if (timer == "immediately") {
      state = true;
      _resetPauseState();
      return true;
    }

    if (!forceImmediate && elapsed < _minBackgroundSeconds) {
      _resetPauseState();
      return false;
    }

    final seconds = int.tryParse(timer);
    if (seconds == null || _pausedAt == null) {
      _resetPauseState();
      return false;
    }

    var shouldLock = false;
    if (elapsed >= seconds) {
      state = true;
      shouldLock = true;
    }

    _resetPauseState();
    return shouldLock;
  }

  /// Manual unlock
  void unlock() {
    state = false;
  }

  /// Force lock now
  void lockNow() {
    state = true;
  }

  Future<void> setLockOnSwitch(bool enabled) async {
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue('auto_lock_on_switch', enabled ? 'true' : 'false');
  }

  /// Temporarily suspend auto-lock (e.g., while launching external scanner)
  void suspendAutoLock() {
    _suspended = true;
  }

  /// Resume auto-lock. In external flow returns, keep default `clearPauseState`
  /// true so overlay transitions do not trigger lock.
  void resumeAutoLock({bool clearPauseState = true}) {
    _suspended = false;
    if (clearPauseState) {
      _resetPauseState();
    }
  }

  void _resetPauseState() {
    _pausedAt = null;
    _forceImmediateOnResume = false;
  }
}

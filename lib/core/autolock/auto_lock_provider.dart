import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';

final autoLockProvider = NotifierProvider<AutoLockController, bool>(
  AutoLockController.new,
);

class AutoLockController extends Notifier<bool> {
  Timer? _timer;

  DateTime? _lastPausedTime; // NEW: store timestamp of background event
  int _autoLockSeconds = 0; // NEW: cache the setting

  @override
  bool build() {
    _loadSettings();
    return false; // unlocked initially
  }

  /// Load auto-lock settings once
  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageProvider);
    final timerValue =
        await storage.readValue("auto_lock_timer") ?? "immediately";

    if (timerValue == "immediately") {
      _autoLockSeconds = 0;
    } else {
      _autoLockSeconds = int.tryParse(timerValue) ?? 0;
    }
  }

  /// Called when app goes to background
  void markPaused() {
    _lastPausedTime = DateTime.now();
    cancelTimer();

    if (_autoLockSeconds == 0) {
      // immediately lock
      state = true;
      return;
    }

    // Start timer for delayed auto-lock
    _timer = Timer(Duration(seconds: _autoLockSeconds), () {
      state = true;
    });
  }

  /// Called when the app resumes
  void evaluateLockOnResume() {
    cancelTimer();

    if (state == true) return; // already locked -> do nothing

    if (_autoLockSeconds == 0) {
      // lock instantly
      state = true;
      return;
    }

    if (_lastPausedTime == null) return; // first run, ignore

    final diff = DateTime.now().difference(_lastPausedTime!);

    if (diff.inSeconds >= _autoLockSeconds) {
      state = true; // lock because timer expired
    }
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void unlock() {
    state = false;
    cancelTimer();
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ironvault/main.dart';

final autoLockProvider = StateNotifierProvider<AutoLockController, bool>((ref) {
  return AutoLockController(ref);
});

class AutoLockController extends StateNotifier<bool> {
  final Ref ref;
  Timer? _timer;

  AutoLockController(this.ref) : super(false);

  void startTimer() async {
    final storage = ref.read(secureStorageProvider);
    final timerValue =
        await storage.readValue("auto_lock_timer") ?? "immediately";

    cancelTimer();

    if (timerValue == "immediately") {
      state = true; // Lock immediately
      return;
    }

    final seconds = int.tryParse(timerValue);
    if (seconds != null) {
      _timer = Timer(Duration(seconds: seconds), () {
        state = true;
      });
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

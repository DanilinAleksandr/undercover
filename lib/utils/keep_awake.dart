import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a round is in progress.
///
/// A table spends minutes talking between taps, and a phone that locks itself
/// mid-discussion breaks the pass-and-play ritual — someone has to unlock it,
/// usually in front of everyone. The lock is released as soon as the game ends.
///
/// Failures are swallowed on purpose: keeping the screen awake is a nicety and
/// must never be able to take down a game in progress.
Future<void> setKeepAwake(bool enabled) async {
  try {
    await WakelockPlus.toggle(enable: enabled);
  } catch (error) {
    debugPrint('Wakelock unavailable, continuing without it: $error');
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final updateReminderProvider =
    StateNotifierProvider<UpdateReminderNotifier, void>((ref) {
  return UpdateReminderNotifier();
});

class UpdateReminderNotifier extends StateNotifier<void> {
  UpdateReminderNotifier() : super(null);

  static const _lastReminderKey = 'last_update_reminder';

  Future<DateTime?> getLastReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastReminderKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> setLastReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReminderKey, DateTime.now().millisecondsSinceEpoch);
  }
}

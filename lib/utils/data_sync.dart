import 'package:flutter/foundation.dart';

/// Global Data Sync Notifier
/// Emits notifications whenever groups, expenses, categories, or category images are modified
class DataSyncNotifier {
  static final ValueNotifier<int> instance = ValueNotifier<int>(0);

  /// Triggers a sync update across all registered screens in the app
  static void notifyDataChanged() {
    instance.value++;
  }
}

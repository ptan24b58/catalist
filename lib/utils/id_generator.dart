import 'dart:math';

/// Generates unique IDs for goals
/// Uses timestamp + random component to avoid collisions
class IdGenerator {
  static final Random _random = Random();

  /// Generate a unique ID
  /// Format: timestamp_random
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999);
    return '${timestamp}_$random';
  }

  /// Validate ID format
  static bool isValid(String id) {
    if (id.isEmpty) return false;
    final parts = id.split('_');
    if (parts.length != 2) return false;

    try {
      int.parse(parts[0]); // timestamp
      int.parse(parts[1]); // random
      return true;
    } catch (e) {
      return false;
    }
  }
}

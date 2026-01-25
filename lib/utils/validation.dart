import 'constants.dart';

/// Input validation utilities
class Validation {
  /// Validate goal title
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a goal title';
    }

    final trimmed = value.trim();
    if (trimmed.length < AppConstants.minTitleLength) {
      return 'Title must be at least ${AppConstants.minTitleLength} character';
    }

    if (trimmed.length > AppConstants.maxTitleLength) {
      return 'Title must be no more than ${AppConstants.maxTitleLength} characters';
    }

    // Check for potentially malicious content (basic sanitization)
    if (_containsInvalidCharacters(trimmed)) {
      return 'Title contains invalid characters';
    }

    return null;
  }

  /// Validate goal target value
  static String? validateTarget(int? value) {
    if (value == null) {
      return 'Target is required';
    }

    if (value < AppConstants.minTarget) {
      return 'Target must be at least ${AppConstants.minTarget}';
    }

    if (value > AppConstants.maxTarget) {
      return 'Target must be no more than ${AppConstants.maxTarget}';
    }

    return null;
  }

  /// Validate goal ID format
  static bool isValidGoalId(String? id) {
    if (id == null || id.isEmpty) {
      return false;
    }

    // Basic validation: non-empty string, reasonable length
    if (id.length > AppConstants.maxIdLength) {
      return false;
    }

    // Check for potentially malicious patterns
    if (_containsInvalidCharacters(id)) {
      return false;
    }

    return true;
  }

  /// Check if string contains potentially dangerous characters
  static bool _containsInvalidCharacters(String value) {
    // Block control characters, but allow normal text
    // This is a basic check - adjust based on your needs
    for (final char in value.runes) {
      if (char < 32 && char != 9 && char != 10 && char != 13) {
        return true; // Control characters except tab, newline, carriage return
      }
    }
    return false;
  }

  /// Sanitize goal title (remove leading/trailing whitespace, normalize)
  static String sanitizeTitle(String title) {
    return title.trim();
  }
}

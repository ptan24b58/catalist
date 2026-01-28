import 'package:flutter/material.dart';

/// Shared dialogs to avoid duplication across screens.
class DialogHelper {
  DialogHelper._();

  /// Shows a delete-goal confirmation. Returns true if user confirmed, false if cancelled.
  static Future<bool> showDeleteGoalConfirmation(
    BuildContext context, {
    required String goalTitle,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "$goalTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

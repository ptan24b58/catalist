import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/collection_item.dart';
import '../domain/goal.dart';
import '../services/goal_image_service.dart';
import '../utils/logger.dart';
import '../utils/id_generator.dart';

/// Callback signature for collection change events
typedef CollectionChangeCallback = Future<void> Function();

/// Repository for managing collection items
class CollectionRepository {
  // Keep the same storage keys to preserve existing data
  static const String _collectionKey = 'memories';
  static const String _migrationKey = 'memories_migration_v1';

  final GoalImageService _imageService = GoalImageService();
  CollectionChangeCallback? _changeListener;

  /// Set a listener to be notified when collection changes
  void setChangeListener(CollectionChangeCallback? listener) {
    _changeListener = listener;
  }

  /// Notify listener of a change
  Future<void> _notifyChange() async {
    if (_changeListener != null) {
      await _changeListener!();
    }
  }

  /// Get all collection items (runs migration on first call)
  Future<List<CollectionItem>> getAllItems() async {
    await _runMigrationIfNeeded();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_collectionKey);

      if (json == null || json.isEmpty) {
        return [];
      }

      // 1MB guard
      if (json.length > 1000000) {
        AppLogger.error('Collection JSON too large, potential corruption');
        return [];
      }

      final decoded = jsonDecode(json);
      if (decoded is! List) {
        AppLogger.error('Invalid collection format: expected List');
        return [];
      }

      return decoded
          .map((item) {
            try {
              if (item is! Map<String, dynamic>) {
                AppLogger.warning('Invalid collection item format: expected Map');
                return null;
              }
              return CollectionItem.fromJson(item);
            } catch (e, stackTrace) {
              AppLogger.warning('Failed to parse collection item from JSON', e);
              AppLogger.debug('Invalid collection item JSON: $item', e, stackTrace);
              return null;
            }
          })
          .whereType<CollectionItem>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load collection', e, stackTrace);
      return [];
    }
  }

  /// Save a collection item (create or update)
  Future<void> saveItem(CollectionItem item) async {
    try {
      final items = await getAllItems();
      final index = items.indexWhere((m) => m.id == item.id);

      if (index >= 0) {
        items[index] = item;
      } else {
        items.add(item);
      }

      await _saveAllItems(items);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save collection item', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a collection item and clean up its image
  Future<void> deleteItem(String id) async {
    try {
      final items = await getAllItems();
      final itemToDelete = items.where((m) => m.id == id).firstOrNull;

      if (itemToDelete?.imagePath != null) {
        await _imageService.deleteImage(itemToDelete!.imagePath);
      }

      items.removeWhere((m) => m.id == id);
      await _saveAllItems(items);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete collection item', e, stackTrace);
      rethrow;
    }
  }

  /// Get a collection item by ID
  Future<CollectionItem?> getItemById(String id) async {
    final items = await getAllItems();
    try {
      return items.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// One-time migration of existing goal completion data to collection
  Future<void> _runMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationKey) == true) return;

      // Read goals directly to avoid circular dependency
      final goalsJson = prefs.getString('goals');
      if (goalsJson == null || goalsJson.isEmpty) {
        await prefs.setBool(_migrationKey, true);
        return;
      }

      final decoded = jsonDecode(goalsJson);
      if (decoded is! List) {
        await prefs.setBool(_migrationKey, true);
        return;
      }

      final goals = decoded
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) return null;
              return Goal.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<Goal>()
          .toList();

      // Find completed long-term goals with image or memo data
      final completedGoals = goals.where((g) =>
          g.goalType == GoalType.longTerm &&
          g.isCompleted &&
          (g.completionImagePath != null || g.completionMemo != null));

      if (completedGoals.isEmpty) {
        await prefs.setBool(_migrationKey, true);
        return;
      }

      // Read existing collection items (if any)
      final existingJson = prefs.getString(_collectionKey);
      final List<CollectionItem> items = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        final existingDecoded = jsonDecode(existingJson);
        if (existingDecoded is List) {
          for (final item in existingDecoded) {
            try {
              if (item is Map<String, dynamic>) {
                items.add(CollectionItem.fromJson(item));
              }
            } catch (_) {}
          }
        }
      }

      // Create collection items from completed goals
      for (final goal in completedGoals) {
        // Skip if already migrated
        if (items.any((m) => m.linkedGoalId == goal.id)) continue;

        final collectionItem = CollectionItem(
          id: IdGenerator.generate(),
          title: goal.title,
          memo: goal.completionMemo,
          imagePath: goal.completionImagePath,
          createdAt: DateTime.now(),
          eventDate: goal.lastCompletedAt ?? goal.createdAt,
          linkedGoalId: goal.id,
          linkedGoalTitle: goal.title,
        );
        items.add(collectionItem);
      }

      // Save migrated items
      final encoded = jsonEncode(items.map((m) => m.toJson()).toList());
      await prefs.setString(_collectionKey, encoded);
      await prefs.setBool(_migrationKey, true);

      AppLogger.info(
          'Migrated ${completedGoals.length} goal completions to collection');
    } catch (e, stackTrace) {
      AppLogger.error('Collection migration failed', e, stackTrace);
      // Don't set flag so it retries next time
    }
  }

  Future<void> _saveAllItems(List<CollectionItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((m) => m.toJson()).toList());
      await prefs.setString(_collectionKey, encoded);
      await _notifyChange();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save collection to storage', e, stackTrace);
      rethrow;
    }
  }
}

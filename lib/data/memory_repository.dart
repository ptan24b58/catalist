import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/memory.dart';
import '../domain/goal.dart';
import '../services/goal_image_service.dart';
import '../utils/logger.dart';
import '../utils/id_generator.dart';

/// Callback signature for memory change events
typedef MemoryChangeCallback = Future<void> Function();

/// Repository for managing memories
class MemoryRepository {
  static const String _memoriesKey = 'memories';
  static const String _migrationKey = 'memories_migration_v1';

  final GoalImageService _imageService = GoalImageService();
  MemoryChangeCallback? _changeListener;

  /// Set a listener to be notified when memories change
  void setChangeListener(MemoryChangeCallback? listener) {
    _changeListener = listener;
  }

  /// Notify listener of a change
  Future<void> _notifyChange() async {
    if (_changeListener != null) {
      await _changeListener!();
    }
  }

  /// Get all memories (runs migration on first call)
  Future<List<Memory>> getAllMemories() async {
    await _runMigrationIfNeeded();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_memoriesKey);

      if (json == null || json.isEmpty) {
        return [];
      }

      // 1MB guard
      if (json.length > 1000000) {
        AppLogger.error('Memories JSON too large, potential corruption');
        return [];
      }

      final decoded = jsonDecode(json);
      if (decoded is! List) {
        AppLogger.error('Invalid memories format: expected List');
        return [];
      }

      return decoded
          .map((item) {
            try {
              if (item is! Map<String, dynamic>) {
                AppLogger.warning('Invalid memory format: expected Map');
                return null;
              }
              return Memory.fromJson(item);
            } catch (e, stackTrace) {
              AppLogger.warning('Failed to parse memory from JSON', e);
              AppLogger.debug('Invalid memory JSON: $item', e, stackTrace);
              return null;
            }
          })
          .whereType<Memory>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load memories', e, stackTrace);
      return [];
    }
  }

  /// Save a memory (create or update)
  Future<void> saveMemory(Memory memory) async {
    try {
      final memories = await getAllMemories();
      final index = memories.indexWhere((m) => m.id == memory.id);

      if (index >= 0) {
        memories[index] = memory;
      } else {
        memories.add(memory);
      }

      await _saveAllMemories(memories);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save memory', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a memory and clean up its image
  Future<void> deleteMemory(String id) async {
    try {
      final memories = await getAllMemories();
      final memoryToDelete = memories.where((m) => m.id == id).firstOrNull;

      if (memoryToDelete?.imagePath != null) {
        await _imageService.deleteImage(memoryToDelete!.imagePath);
      }

      memories.removeWhere((m) => m.id == id);
      await _saveAllMemories(memories);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete memory', e, stackTrace);
      rethrow;
    }
  }

  /// Get a memory by ID
  Future<Memory?> getMemoryById(String id) async {
    final memories = await getAllMemories();
    try {
      return memories.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// One-time migration of existing goal completion data to memories
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

      // Read existing memories (if any)
      final existingJson = prefs.getString(_memoriesKey);
      final List<Memory> memories = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        final existingDecoded = jsonDecode(existingJson);
        if (existingDecoded is List) {
          for (final item in existingDecoded) {
            try {
              if (item is Map<String, dynamic>) {
                memories.add(Memory.fromJson(item));
              }
            } catch (_) {}
          }
        }
      }

      // Create memories from completed goals
      for (final goal in completedGoals) {
        // Skip if already migrated
        if (memories.any((m) => m.linkedGoalId == goal.id)) continue;

        final memory = Memory(
          id: IdGenerator.generate(),
          title: goal.title,
          memo: goal.completionMemo,
          imagePath: goal.completionImagePath,
          createdAt: DateTime.now(),
          eventDate: goal.lastCompletedAt ?? goal.createdAt,
          linkedGoalId: goal.id,
          linkedGoalTitle: goal.title,
        );
        memories.add(memory);
      }

      // Save migrated memories
      final encoded = jsonEncode(memories.map((m) => m.toJson()).toList());
      await prefs.setString(_memoriesKey, encoded);
      await prefs.setBool(_migrationKey, true);

      AppLogger.info(
          'Migrated ${completedGoals.length} goal completions to memories');
    } catch (e, stackTrace) {
      AppLogger.error('Memory migration failed', e, stackTrace);
      // Don't set flag so it retries next time
    }
  }

  Future<void> _saveAllMemories(List<Memory> memories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(memories.map((m) => m.toJson()).toList());
      await prefs.setString(_memoriesKey, encoded);
      await _notifyChange();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save memories to storage', e, stackTrace);
      rethrow;
    }
  }
}

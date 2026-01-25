import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widget_snapshot.dart';
import '../domain/mascot_state.dart';

class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({super.key});

  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen> {
  final WidgetSnapshotService _snapshotService = WidgetSnapshotService();
  WidgetSnapshot? _snapshot;
  bool _isLoading = true;

  // Duolingo-inspired color palette
  static const _happyGreen = Color(0xFF58CC02);
  static const _neutralBlue = Color(0xFF1CB0F6);
  static const _worriedOrange = Color(0xFFFF9600);
  static const _sadRed = Color(0xFFFF4B4B);
  static const _celebrateGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() => _isLoading = true);
    final snapshot = await _snapshotService.getSnapshot();
    if (snapshot == null) {
      await _snapshotService.generateSnapshot();
      final newSnapshot = await _snapshotService.getSnapshot();
      setState(() {
        _snapshot = newSnapshot;
        _isLoading = false;
      });
    } else {
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    }
  }

  Color _getEmotionColor(MascotEmotion emotion) {
    switch (emotion) {
      case MascotEmotion.happy:
        return _happyGreen;
      case MascotEmotion.neutral:
        return _neutralBlue;
      case MascotEmotion.worried:
        return _worriedOrange;
      case MascotEmotion.sad:
        return _sadRed;
      case MascotEmotion.celebrate:
        return _celebrateGold;
    }
  }

  String _getEmotionMessage(MascotEmotion emotion) {
    switch (emotion) {
      case MascotEmotion.happy:
        return "You're doing great!";
      case MascotEmotion.neutral:
        return "Let's keep going!";
      case MascotEmotion.worried:
        return "Don't forget me...";
      case MascotEmotion.sad:
        return "I miss you!";
      case MascotEmotion.celebrate:
        return "Amazing work!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Widget Preview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await _snapshotService.generateSnapshot();
              await _loadSnapshot();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home Screen Widgets',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your cat shows how you\'re doing with your goals',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Small Widget
                  _buildSectionLabel('Small'),
                  const SizedBox(height: 12),
                  Center(child: _buildSmallWidget()),

                  const SizedBox(height: 40),

                  // Medium Widget
                  _buildSectionLabel('Medium'),
                  const SizedBox(height: 12),
                  _buildMediumWidget(),

                  const SizedBox(height: 40),

                  // Emotion States Preview
                  _buildSectionLabel('Cat Moods'),
                  const SizedBox(height: 12),
                  _buildEmotionPreview(),

                  const SizedBox(height: 40),

                  // Debug Data (collapsible)
                  _buildSnapshotData(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSmallWidget() {
    final emotion = _snapshot?.mascot.emotion ?? MascotEmotion.neutral;
    final color = _getEmotionColor(emotion);
    final goal = _snapshot?.topGoal;

    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ),
            // Cat - Main focus
            Positioned.fill(
              child: Image.asset(
                'assets/cat.png',
                fit: BoxFit.cover,
              ),
            ),
            // Top task text
            if (goal != null)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumWidget() {
    final emotion = _snapshot?.mascot.emotion ?? MascotEmotion.neutral;
    final color = _getEmotionColor(emotion);
    final goal = _snapshot?.topGoal;
    final message = _getEmotionMessage(emotion);

    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              right: -40,
              bottom: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Cat - Main focus
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Image.asset(
                      'assets/cat.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Speech bubble
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Goal info
                        if (goal != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: goal.goalType == 'daily'
                                      ? _neutralBlue.withValues(alpha: 0.2)
                                      : _worriedOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  goal.goalType == 'daily' ? 'Daily' : 'Goal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: goal.goalType == 'daily'
                                        ? _neutralBlue
                                        : _worriedOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: goal.progress,
                                    backgroundColor: Colors.white,
                                    valueColor: AlwaysStoppedAnimation(color),
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                goal.progressLabel ?? '${(goal.progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmotionIcon(MascotEmotion emotion) {
    switch (emotion) {
      case MascotEmotion.happy:
        return Icons.sentiment_very_satisfied_rounded;
      case MascotEmotion.neutral:
        return Icons.sentiment_neutral_rounded;
      case MascotEmotion.worried:
        return Icons.sentiment_dissatisfied_rounded;
      case MascotEmotion.sad:
        return Icons.sentiment_very_dissatisfied_rounded;
      case MascotEmotion.celebrate:
        return Icons.star_rounded;
    }
  }

  Widget _buildEmotionPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: MascotEmotion.values.map((emotion) {
          final color = _getEmotionColor(emotion);
          final isCurrentEmotion = _snapshot?.mascot.emotion == emotion;
          return Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isCurrentEmotion ? 1.0 : 0.15),
                  shape: BoxShape.circle,
                  border: isCurrentEmotion
                      ? Border.all(color: color, width: 3)
                      : null,
                  boxShadow: isCurrentEmotion
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _getEmotionIcon(emotion),
                  color: isCurrentEmotion ? Colors.white : color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emotion.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isCurrentEmotion ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrentEmotion ? color : Colors.grey[600],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSnapshotData() {
    if (_snapshot == null) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: Text(
        'Debug Info',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDataRow('Version', _snapshot!.version.toString()),
              _buildDataRow(
                'Generated',
                DateFormat('MMM d, h:mm:ss a').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    _snapshot!.generatedAt * 1000,
                  ),
                ),
              ),
              if (_snapshot!.topGoal != null) ...[
                const Divider(height: 20),
                _buildDataRow('Goal', _snapshot!.topGoal!.title),
                _buildDataRow('Type', _snapshot!.topGoal!.goalType),
                _buildDataRow(
                  'Progress',
                  _snapshot!.topGoal!.progressLabel ?? 
                      '${(_snapshot!.topGoal!.progress * 100).toInt()}%',
                ),
                _buildDataRow(
                  'Urgency',
                  _snapshot!.topGoal!.urgency.toStringAsFixed(2),
                ),
              ],
              const Divider(height: 20),
              _buildDataRow('Emotion', _snapshot!.mascot.emotion.name),
              _buildDataRow('Frame', _snapshot!.mascot.frameIndex.toString()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

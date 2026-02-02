import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'dot_lottie_asset.dart';

const _kDuration = Duration(milliseconds: 3650);
const _kAssetPath = 'assets/celebration/fireworks.lottie';

/// Full-screen celebration overlay (fireworks). Auto-dismisses after 4 seconds.
/// Call from goals list or goal detail when a goal is completed.
void showCelebrationOverlay(BuildContext context) {
  if (!context.mounted) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => const _CelebrationOverlayContent(),
    );
  });
}

class _CelebrationOverlayContent extends StatefulWidget {
  const _CelebrationOverlayContent();

  @override
  State<_CelebrationOverlayContent> createState() =>
      _CelebrationOverlayContentState();
}

class _CelebrationOverlayContentState extends State<_CelebrationOverlayContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_kDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).shortestSide.clamp(240.0, 600.0);
    return SizedBox.expand(
      child: Center(
        child: SizedBox.square(
          dimension: side,
          child: DotLottieAsset(
            _kAssetPath,
            fit: BoxFit.contain,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.error('Celebration Lottie failed', error, stackTrace);
              return ColoredBox(color: Colors.black.withValues(alpha: 0.4));
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Simple XP indicator - no animation, just shows earned XP briefly
class XPBurst extends StatefulWidget {
  final int xpAmount;
  final VoidCallback? onComplete;

  const XPBurst({
    super.key,
    required this.xpAmount,
    this.onComplete,
  });

  @override
  State<XPBurst> createState() => _XPBurstState();
}

class _XPBurstState extends State<XPBurst> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Simple fade out after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.xpGreen,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.xpGreen.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '+${widget.xpAmount} XP',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Overlay for showing XP notifications
class XPBurstOverlay extends StatefulWidget {
  final Widget child;

  const XPBurstOverlay({
    super.key,
    required this.child,
  });

  static XPBurstOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<XPBurstOverlayState>();
  }

  @override
  State<XPBurstOverlay> createState() => XPBurstOverlayState();
}

class XPBurstOverlayState extends State<XPBurstOverlay> {
  final List<_XPEntry> _bursts = [];
  int _nextId = 0;

  void showXPBurst(int amount, {Offset? position}) {
    final id = _nextId++;
    setState(() {
      _bursts.add(_XPEntry(id: id, amount: amount));
    });
  }

  void _removeBurst(int id) {
    setState(() {
      _bursts.removeWhere((b) => b.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._bursts.map((burst) {
          return Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            child: Center(
              child: XPBurst(
                xpAmount: burst.amount,
                onComplete: () => _removeBurst(burst.id),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _XPEntry {
  final int id;
  final int amount;

  _XPEntry({required this.id, required this.amount});
}

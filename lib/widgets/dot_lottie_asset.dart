import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Convenience widget that loads a .lottie (dotLottie) asset and renders it
/// via the standard [Lottie] player.
class DotLottieAsset extends StatelessWidget {
  const DotLottieAsset(
    this.assetPath, {
    super.key,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.errorBuilder,
  });

  final String assetPath;
  final BoxFit fit;
  final bool repeat;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return DotLottieLoader.fromAsset(
      assetPath,
      frameBuilder: (ctx, dotlottie) {
        if (dotlottie != null) {
          return Lottie.memory(
            dotlottie.animations.values.single,
            fit: fit,
            repeat: repeat,
            errorBuilder: errorBuilder,
            imageProviderFactory: dotlottie.images.isNotEmpty
                ? (asset) {
                    final bytes = dotlottie.images[asset.fileName];
                    if (bytes != null) return MemoryImage(bytes);
                    return AssetImage(asset.fileName);
                  }
                : null,
          );
        }
        return const SizedBox.shrink();
      },
      errorBuilder: errorBuilder != null
          ? (ctx, error, stackTrace) => errorBuilder!(ctx, error, stackTrace)
          : null,
    );
  }
}

import 'dart:ui';

import 'package:better_player/better_player.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';

///Wraps the player with a blurred replica of the current video to emulate Ambient Mode.
class BetterPlayerAmbientBackdrop extends StatelessWidget {
  const BetterPlayerAmbientBackdrop({
    required this.controller,
    required this.child,
    super.key,
  });

  final BetterPlayerController controller;
  final Widget child;

  bool _shouldShowAmbient(BuildContext context) {
    final configuration = controller.betterPlayerConfiguration;

    if (!configuration.enableAmbientMode) {
      return false;
    }

    if (configuration.ambientModeFullScreenOnly && !controller.isFullScreen) {
      return false;
    }

    if (configuration.ambientModeLandscapeOnly) {
      final orientation = MediaQuery.maybeOf(context)?.orientation;
      if (orientation == null || orientation != Orientation.landscape) {
        return false;
      }
    }

    final videoController = controller.videoPlayerController;
    if (videoController == null || !videoController.value.initialized) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackColor = controller
        .betterPlayerConfiguration.controlsConfiguration.backgroundColor;

    if (!_shouldShowAmbient(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(color: fallbackColor),
        child: child,
      );
    }

    final configuration = controller.betterPlayerConfiguration;
    final blurSigma = configuration.ambientBlurSigma.clamp(0, 100).toDouble();
    final scale = configuration.ambientScale.clamp(1.0, 2.0);
    final darken = configuration.ambientDarken.clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity:
                  controller.videoPlayerController?.value.initialized == true
                      ? 1
                      : 0,
              duration: const Duration(milliseconds: 300),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: _AmbientVideoSurface(
                          controller: controller,
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: darken),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientVideoSurface extends StatelessWidget {
  const _AmbientVideoSurface({
    required this.controller,
  });

  final BetterPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoController = controller.videoPlayerController;
    if (videoController == null ||
        !videoController.value.initialized ||
        videoController.value.size == null ||
        videoController.value.size == Size.zero) {
      return const SizedBox();
    }

    final size = videoController.value.size!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(videoController),
      ),
    );
  }
}
